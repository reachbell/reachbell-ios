import Foundation

final class TokenStore: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var apnsToken: String? {
        get { defaults.string(forKey: ReachBellConstants.StorageKey.apnsToken) }
        set { write(newValue, forKey: ReachBellConstants.StorageKey.apnsToken) }
    }

    var externalId: String? {
        get { defaults.string(forKey: ReachBellConstants.StorageKey.externalId) }
        set { write(newValue, forKey: ReachBellConstants.StorageKey.externalId) }
    }

    var registeredToken: String? {
        get { defaults.string(forKey: ReachBellConstants.StorageKey.registeredToken) }
        set { write(newValue, forKey: ReachBellConstants.StorageKey.registeredToken) }
    }

    /// C1a: set by `clear()`, dropped after the next successful registration.
    var externalIdClearPending: Bool {
        get { defaults.bool(forKey: ReachBellConstants.StorageKey.externalIdClearPending) }
        set {
            if newValue {
                defaults.set(true, forKey: ReachBellConstants.StorageKey.externalIdClearPending)
            } else {
                defaults.removeObject(forKey: ReachBellConstants.StorageKey.externalIdClearPending)
            }
        }
    }

    func clear() {
        defaults.removeObject(forKey: ReachBellConstants.StorageKey.apnsToken)
        defaults.removeObject(forKey: ReachBellConstants.StorageKey.externalId)
        defaults.removeObject(forKey: ReachBellConstants.StorageKey.registeredToken)
        externalIdClearPending = true
    }

    private func write(_ value: String?, forKey key: String) {
        if let value = value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
