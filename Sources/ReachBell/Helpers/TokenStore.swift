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

    func clear() {
        defaults.removeObject(forKey: ReachBellConstants.StorageKey.apnsToken)
        defaults.removeObject(forKey: ReachBellConstants.StorageKey.externalId)
    }

    private func write(_ value: String?, forKey key: String) {
        if let value = value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
