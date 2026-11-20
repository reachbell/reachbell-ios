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
        var pendingRegistration: Task<Void, Never>?
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
            store.apnsToken = token
            let previous = current.pendingRegistration
            current.pendingRegistration = Task {
                await previous?.value
                await self.performRegistration()
            }
        }
    }

    private func performRegistration() async {
        guard !Task.isCancelled else {
            return
        }
        let result: Result<Void, ReachBellError>
        do {
            try await register()
            result = .success(())
        } catch let error as ReachBellError {
            result = .failure(error)
        } catch {
            result = .failure(.network(underlying: error))
        }
        onRegistrationResult?(result)
    }

    public func register() async throws {
        let client = try makeClient()
        let (token, externalId) = state.read { _ in (store.apnsToken, store.externalId) }
        guard let token = token else {
            throw ReachBellError.noToken
        }
        let body = RegisterSubscriberBody(
            token: token,
            tokenType: ReachBellConstants.Subscriber.tokenType,
            platform: ReachBellConstants.Subscriber.platform,
            externalId: externalId
        )
        _ = try await client.post(ReachBellConstants.Path.subscribers, body: body)
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

    public func reset() {
        state.mutate { current in
            current.pendingRegistration?.cancel()
            current.pendingRegistration = nil
            store.clear()
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
