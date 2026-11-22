import Foundation

enum ReachBellConstants {
    static let defaultApiUrl = "https://api.reachbell.com"
    static let sdkVersion = "1.0.0"
    static let requestTimeout: TimeInterval = 30

    enum Header {
        static let apiKey = "x-api-key"
        static let contentType = "Content-Type"
        static let accept = "Accept"
        static let userAgent = "User-Agent"
        static let json = "application/json"
    }

    enum Path {
        static let subscribers = "/subscribers"
        static let identify = "/subscribers/identify"
        static let unidentify = "/subscribers/unidentify"
        static let tag = "/subscribers/tag"
        static let untag = "/subscribers/untag"
    }

    enum Subscriber {
        static let tokenType = "apns"
        static let platform = "ios"
    }

    enum StorageKey {
        static let apnsToken = "com.reachbell.apnsToken"
        static let externalId = "com.reachbell.externalId"
        /// The subscriber token of the last successful `POST /subscribers`, sent as `previousToken` when APNs rotates it.
        static let registeredToken = "com.reachbell.registeredToken"
        /// Set by `reset()`: the next `POST /subscribers` without an external id sends `"externalId": null`.
        static let externalIdClearPending = "com.reachbell.externalIdClearPending"
    }
}
