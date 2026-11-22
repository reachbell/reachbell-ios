import Foundation
#if canImport(UIKit) && canImport(UserNotifications) && !os(watchOS)
import UserNotifications
#endif

public final class ReachBell: @unchecked Sendable {
    public typealias RegistrationResultHandler = @Sendable (Result<Void, ReachBellError>) -> Void

    public static let shared = ReachBell()

    private struct State {
        var configuration: ReachBellConfiguration?
        var onRegistrationResult: RegistrationResultHandler?
        /// The tail of the background work chain: registrations from `setAPNsToken(_:)` and the
        /// unidentify call from `reset()`. identify/tag/untag wait for it.
        var pendingRegistration: Task<Void, Never>?
        /// Whether `pendingRegistration` is a registration (cancelled by `reset()`) rather than a reset.
        var pendingIsRegistration = false
        /// Bumped by `reset()`. Work started under an older generation does not report or persist results.
        var generation = 0
    }

    private let state = Locked(State())
    private let store: TokenStore
    private let transport: ReachBellTransport

    public init(
        userDefaults: UserDefaults = .standard,
        transport: ReachBellTransport = URLSessionTransport()
    ) {
        self.store = TokenStore(defaults: userDefaults)
        self.transport = transport
    }

    public func configure(apiKey: String, apiUrl: String = ReachBell.defaultApiUrl) {
        let configuration = ReachBellConfiguration(apiKey: apiKey, apiUrl: URLJoin.normalizedBase(apiUrl))
        state.mutate { $0.configuration = configuration }
    }

    public static let defaultApiUrl = ReachBellConstants.defaultApiUrl

    public static let version = ReachBellConstants.sdkVersion

    public var onRegistrationResult: RegistrationResultHandler? {
        get { state.read { $0.onRegistrationResult } }
        set { state.mutate { $0.onRegistrationResult = newValue } }
    }

    public var apnsToken: String? {
        state.read { _ in store.apnsToken }
    }

    public var externalId: String? {
        state.read { _ in store.externalId }
    }

    public func setAPNsToken(_ deviceToken: Data) {
        let token = deviceToken.lowercaseHexString
        state.mutate { current in
            if store.registeredToken == nil, let stored = store.apnsToken, stored != token {
                // 1.0.0 did not record the registered token separately; the stored one is it.
                store.registeredToken = stored
            }
            store.apnsToken = token
            let previous = current.pendingRegistration
            let generation = current.generation
            current.pendingIsRegistration = true
            current.pendingRegistration = Task {
                await previous?.value
                await self.performRegistration(generation: generation)
            }
        }
    }

    private func performRegistration(generation: Int) async {
        guard !Task.isCancelled, isCurrent(generation) else {
            return
        }
        let result: Result<Void, ReachBellError>
        do {
            try await register(expectedGeneration: generation)
            result = .success(())
        } catch let error as ReachBellError {
            result = .failure(error)
        } catch {
            result = .failure(.network(underlying: error))
        }
        // reset() ran while the request was in flight: the result belongs to the previous user.
        guard !Task.isCancelled, isCurrent(generation) else {
            return
        }
        onRegistrationResult?(result)
    }

    public func register() async throws {
        try await register(expectedGeneration: nil)
    }

    private func register(expectedGeneration: Int?) async throws {
        let client = try makeClient()
        let (token, externalId, registered, clearPending, generation) = state.read { current in
            (store.apnsToken, store.externalId, store.registeredToken, store.externalIdClearPending, current.generation)
        }
        if let expected = expectedGeneration, expected != generation {
            return
        }
        guard let token = token else {
            throw ReachBellError.noToken
        }
        let device = DeviceInfo.current
        let body = RegisterSubscriberBody(
            token: token,
            tokenType: ReachBellConstants.Subscriber.tokenType,
            platform: ReachBellConstants.Subscriber.platform,
            externalId: externalId,
            previousToken: registered == token ? nil : registered,
            os: device.os,
            osVersion: device.osVersion,
            device: device.deviceType,
            // C1a: after reset(), the first registration without an external id clears it server-side.
            clearExternalId: externalId == nil && clearPending
        )
        _ = try await client.post(ReachBellConstants.Path.subscribers, body: body)
        state.mutate { current in
            // Do not resurrect a subscription that reset() cleared while the request was in flight.
            if current.generation == generation {
                store.registeredToken = token
                store.externalIdClearPending = false
            }
        }
    }

    private func isCurrent(_ generation: Int) -> Bool {
        state.read { $0.generation == generation }
    }

    public func identify(_ externalId: String) async throws {
        let client = try makeClient()
        await waitForPendingRegistration()
        let token: String? = state.mutate { _ in
            store.externalId = externalId
            return store.apnsToken
        }
        guard let token = token else {
            return
        }
        try await client.mutate(
            ReachBellConstants.Path.identify,
            body: IdentifyBody(token: token, externalId: externalId)
        )
    }

    public func tag(_ tags: [String]) async throws {
        try await sendTags(tags, to: ReachBellConstants.Path.tag)
    }

    public func untag(_ tags: [String]) async throws {
        try await sendTags(tags, to: ReachBellConstants.Path.untag)
    }

    /// Logs the device out. Forgets the stored token and external id immediately, cancels an in-flight
    /// registration (its result is dropped) and, in the background, calls `POST /subscribers/unidentify`
    /// for the token that was stored (best effort, errors are ignored). `identify`, `tag`, `untag` and the
    /// next registration wait for that call. The APNs token is forgotten too: call
    /// `registerForRemoteNotifications()` again so `setAPNsToken(_:)` registers the device for the next user.
    public func reset() {
        let client = try? makeClient()
        state.mutate { current in
            current.generation += 1
            // After an APNs rotation whose registration is in flight (or failed), registeredToken is the
            // old subscriber and apnsToken the new one, which the API may already have linked to the
            // user: unidentify both so neither keeps the old user's external id.
            let registered = store.registeredToken
            let apns = store.apnsToken
            let tokens = registered == apns ? [apns].compactMap { $0 } : [registered, apns].compactMap { $0 }
            let previous = current.pendingRegistration
            if current.pendingIsRegistration {
                previous?.cancel()
            }
            store.clear()
            current.pendingIsRegistration = false
            current.pendingRegistration = Task {
                await previous?.value
                guard let client = client else {
                    return
                }
                for token in tokens {
                    try? await client.mutate(
                        ReachBellConstants.Path.unidentify,
                        body: UnidentifyBody(token: token)
                    )
                }
            }
        }
    }

    public func waitForPendingRegistration() async {
        let pending = state.read { $0.pendingRegistration }
        await pending?.value
    }

    #if canImport(UIKit) && canImport(UserNotifications) && !os(watchOS)
    @discardableResult
    public func requestAuthorizationAndRegister(
        options: UNAuthorizationOptions = [.alert, .sound, .badge]
    ) async throws -> Bool {
        _ = try makeClient()
        let granted: Bool
        do {
            granted = try await NotificationAuthorization.request(options: options)
        } catch {
            throw ReachBellError.notificationAuthorizationDenied
        }
        guard granted else {
            throw ReachBellError.notificationAuthorizationDenied
        }
        await NotificationAuthorization.registerForRemoteNotifications()
        return granted
    }
    #endif

    private func sendTags(_ tags: [String], to path: String) async throws {
        let client = try makeClient()
        await waitForPendingRegistration()
        guard let token = apnsToken else {
            throw ReachBellError.noToken
        }
        try await client.mutate(path, body: TagsBody(token: token, tags: tags))
    }

    private func makeClient() throws -> APIClient {
        guard let configuration = state.read({ $0.configuration }), !configuration.apiKey.isEmpty else {
            throw ReachBellError.notConfigured
        }
        return APIClient(configuration: configuration, transport: transport)
    }
}
