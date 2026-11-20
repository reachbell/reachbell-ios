import Foundation

struct APIClient: Sendable {
    let configuration: ReachBellConfiguration
    let transport: ReachBellTransport

    func post<Body: Encodable>(_ path: String, body: Body) async throws -> Data {
        guard let url = URLJoin.url(base: configuration.apiUrl, path: path) else {
            throw ReachBellError.network(underlying: URLError(.badURL))
        }

        let payload: Data
        do {
            payload = try JSONEncoder().encode(body)
        } catch {
            throw ReachBellError.encodingFailed(error)
        }

        var request = URLRequest(url: url, timeoutInterval: ReachBellConstants.requestTimeout)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue(ReachBellConstants.Header.json, forHTTPHeaderField: ReachBellConstants.Header.contentType)
        request.setValue(ReachBellConstants.Header.json, forHTTPHeaderField: ReachBellConstants.Header.accept)
        request.setValue(configuration.apiKey, forHTTPHeaderField: ReachBellConstants.Header.apiKey)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as ReachBellError {
            throw error
        } catch {
            throw ReachBellError.network(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ReachBellError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ReachBellError.server(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        return data
    }

    func mutate<Body: Encodable>(_ path: String, body: Body) async throws {
        let data = try await post(path, body: body)
        let result: MutationResponse
        do {
            result = try JSONDecoder().decode(MutationResponse.self, from: data)
        } catch {
            throw ReachBellError.invalidResponse
        }
        guard result.success else {
            throw ReachBellError.rejected(reason: result.reason)
        }
    }
}
