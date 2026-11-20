import Foundation

public protocol ReachBellTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}
