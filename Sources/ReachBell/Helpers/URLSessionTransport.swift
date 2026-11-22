import Foundation

public struct URLSessionTransport: ReachBellTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Cancelling the calling task cancels the underlying `URLSessionDataTask`, which then fails with
    /// `URLError(.cancelled)`.
    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let handle = DataTaskHandle()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let response = response {
                        continuation.resume(returning: (data ?? Data(), response))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                handle.start(task)
            }
        } onCancel: {
            handle.cancel()
        }
    }
}

/// Lets the cancellation handler reach a data task that may not have been created yet.
private final class DataTaskHandle: @unchecked Sendable {
    private struct State {
        var task: URLSessionDataTask?
        var cancelled = false
    }

    private let state = Locked(State())

    func start(_ task: URLSessionDataTask) {
        let alreadyCancelled: Bool = state.mutate { current in
            current.task = task
            return current.cancelled
        }
        task.resume()
        if alreadyCancelled {
            task.cancel()
        }
    }

    func cancel() {
        let task: URLSessionDataTask? = state.mutate { current in
            current.cancelled = true
            return current.task
        }
        task?.cancel()
    }
}
