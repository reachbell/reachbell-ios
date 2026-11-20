import Foundation

public enum ReachBellError: Error {
    case notConfigured
    case notificationAuthorizationDenied
    case noToken
    case encodingFailed(Error)
    case network(underlying: Error)
    case server(status: Int, body: String)
    case invalidResponse
    case rejected(reason: String?)
}

extension ReachBellError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ReachBell is not configured. Call configure(apiKey:) first."
        case .notificationAuthorizationDenied:
            return "The user denied notification permission."
        case .noToken:
            return "No APNs token yet. Register for push first."
        case .encodingFailed(let error):
            return "The request body could not be encoded: \(error.localizedDescription)"
        case .network(let underlying):
            return "The request failed: \(underlying.localizedDescription)"
        case .server(let status, let body):
            return "ReachBell responded with HTTP \(status): \(body)"
        case .invalidResponse:
            return "ReachBell returned an invalid response."
        case .rejected(let reason):
            return "ReachBell rejected the request: \(reason ?? "unknown reason")"
        }
    }
}
