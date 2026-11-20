import Foundation
@testable import ReachBell

final class MockTransport: ReachBellTransport, @unchecked Sendable {
    enum Reply {
        case json(status: Int, body: String)
        case failure(Error)
    }

    private struct Queue {
        var replies: [Reply]
        var recorded: [URLRequest] = []
    }

    private let queue: Locked<Queue>

    init(replies: [Reply] = []) {
        self.queue = Locked(Queue(replies: replies))
    }

    var requests: [URLRequest] {
        queue.read { $0.recorded }
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let reply: Reply = queue.mutate { current in
            current.recorded.append(request)
            return current.replies.isEmpty
                ? .json(status: 200, body: "{\"success\":true,\"updated\":true}")
                : current.replies.removeFirst()
        }

        switch reply {
        case .json(let status, let body):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (Data(body.utf8), response)
        case .failure(let error):
            throw error
        }
    }
}

func jsonBody(_ request: URLRequest) -> [String: Any] {
    guard let data = request.httpBody,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return [:]
    }
    return object
}

func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let suite = "reachbell.tests.\(name)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}
