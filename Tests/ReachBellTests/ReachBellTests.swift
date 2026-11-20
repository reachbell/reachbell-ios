import XCTest
@testable import ReachBell

final class ReachBellTests: XCTestCase {
    private let tokenData = Data([0xde, 0xad, 0xbe, 0xef, 0x01, 0x0a])
    private let tokenHex = "deadbeef010a"

    private func makeClient(_ transport: MockTransport, defaults: UserDefaults = makeDefaults()) -> ReachBell {
        let client = ReachBell(userDefaults: defaults, transport: transport)
        client.configure(apiKey: "rb_live_test", apiUrl: "https://api.example.test/")
        return client
    }

    private func registrationResult(_ client: ReachBell, after action: () -> Void) -> Result<Void, ReachBellError>? {
        let done = expectation(description: "registration")
        let box = ResultBox()
        client.onRegistrationResult = { result in
            box.set(result)
            done.fulfill()
        }
        action()
        wait(for: [done], timeout: 5)
        return box.value
    }

    func testSetAPNsTokenRegistersWithHexToken() throws {
        let transport = MockTransport(replies: [.json(status: 201, body: "{\"_id\":\"sub_1\"}")])
        let client = makeClient(transport)

        let result = registrationResult(client) { client.setAPNsToken(tokenData) }

        guard case .success = result else { return XCTFail("expected success, got \(String(describing: result))") }
        XCTAssertEqual(client.apnsToken, tokenHex)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.test/subscribers")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "rb_live_test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = jsonBody(request)
        XCTAssertEqual(body["token"] as? String, tokenHex)
        XCTAssertEqual(body["tokenType"] as? String, "apns")
        XCTAssertEqual(body["platform"] as? String, "ios")
        XCTAssertNil(body["externalId"])
    }

    func testIdentifyBeforeTokenIsStashedAndFoldedIntoRegistration() async throws {
        let transport = MockTransport()
        let client = makeClient(transport)

        try await client.identify("user_42")
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(client.externalId, "user_42")

        client.setAPNsToken(tokenData)
        await client.waitForPendingRegistration()

        XCTAssertEqual(transport.requests.count, 1)
        let body = jsonBody(transport.requests[0])
        XCTAssertEqual(transport.requests[0].url?.path, "/subscribers")
        XCTAssertEqual(body["externalId"] as? String, "user_42")
        XCTAssertEqual(body["token"] as? String, tokenHex)
    }

    func testIdentifyWithTokenCallsIdentifyEndpoint() async throws {
        let transport = MockTransport()
        let client = makeClient(transport)
        client.setAPNsToken(tokenData)

        try await client.identify("user_7")

        XCTAssertEqual(transport.requests.map { $0.url?.path }, ["/subscribers", "/subscribers/identify"])
        let body = jsonBody(transport.requests[1])
        XCTAssertEqual(body["token"] as? String, tokenHex)
        XCTAssertEqual(body["externalId"] as? String, "user_7")
    }

    func testTagWithoutTokenThrowsNoToken() async {
        let transport = MockTransport()
        let client = makeClient(transport)

        do {
            try await client.tag(["pro"])
            XCTFail("expected noToken")
        } catch ReachBellError.noToken {
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testTagAndUntagSendTokenAndTags() async throws {
        let transport = MockTransport()
        let client = makeClient(transport)
        client.setAPNsToken(tokenData)

        try await client.tag(["pro", "ios"])
        try await client.untag(["ios"])

        XCTAssertEqual(transport.requests.map { $0.url?.path }, ["/subscribers", "/subscribers/tag", "/subscribers/untag"])
        XCTAssertEqual(jsonBody(transport.requests[1])["tags"] as? [String], ["pro", "ios"])
        XCTAssertEqual(jsonBody(transport.requests[2])["tags"] as? [String], ["ios"])
        XCTAssertEqual(jsonBody(transport.requests[2])["token"] as? String, tokenHex)
    }

    func testNon2xxThrowsServer() async {
        let transport = MockTransport(replies: [
            .json(status: 201, body: "{}"),
            .json(status: 403, body: "{\"error\":\"limit\"}")
        ])
        let client = makeClient(transport)
        client.setAPNsToken(tokenData)

        do {
            try await client.tag(["pro"])
            XCTFail("expected server error")
        } catch ReachBellError.server(let status, let body) {
            XCTAssertEqual(status, 403)
            XCTAssertEqual(body, "{\"error\":\"limit\"}")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testRegistrationFailureIsReportedThroughCallback() {
        let transport = MockTransport(replies: [.json(status: 403, body: "plan limit")])
        let client = makeClient(transport)

        let result = registrationResult(client) { client.setAPNsToken(tokenData) }

        guard case .failure(.server(let status, let body)) = result else {
            return XCTFail("expected server failure, got \(String(describing: result))")
        }
        XCTAssertEqual(status, 403)
        XCTAssertEqual(body, "plan limit")
    }

    func testSuccessFalseThrowsRejected() async {
        let transport = MockTransport(replies: [
            .json(status: 201, body: "{}"),
            .json(status: 200, body: "{\"success\":false,\"updated\":false,\"reason\":\"subscriber_not_found\"}")
        ])
        let client = makeClient(transport)
        client.setAPNsToken(tokenData)

        do {
            try await client.identify("user_1")
            XCTFail("expected rejected")
        } catch ReachBellError.rejected(let reason) {
            XCTAssertEqual(reason, "subscriber_not_found")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testTransportFailureThrowsNetwork() async {
        let transport = MockTransport(replies: [
            .json(status: 201, body: "{}"),
            .failure(URLError(.notConnectedToInternet))
        ])
        let client = makeClient(transport)
        client.setAPNsToken(tokenData)

        do {
            try await client.tag(["pro"])
            XCTFail("expected network error")
        } catch ReachBellError.network(let underlying) {
            XCTAssertEqual((underlying as? URLError)?.code, .notConnectedToInternet)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testNonJSONSuccessBodyThrowsInvalidResponse() async {
        let transport = MockTransport(replies: [
            .json(status: 201, body: "{}"),
            .json(status: 200, body: "ok")
        ])
        let client = makeClient(transport)
        client.setAPNsToken(tokenData)

        do {
            try await client.tag(["pro"])
            XCTFail("expected invalidResponse")
        } catch ReachBellError.invalidResponse {
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testNotConfiguredThrows() async {
        let client = ReachBell(userDefaults: makeDefaults(), transport: MockTransport())

        do {
            try await client.identify("user_1")
            XCTFail("expected notConfigured")
        } catch ReachBellError.notConfigured {
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testTokenAndExternalIdPersistAcrossInstances() async throws {
        let defaults = makeDefaults()
        let first = makeClient(MockTransport(), defaults: defaults)
        try await first.identify("user_9")
        first.setAPNsToken(tokenData)
        await first.waitForPendingRegistration()

        let transport = MockTransport()
        let second = makeClient(transport, defaults: defaults)
        XCTAssertEqual(second.apnsToken, tokenHex)
        XCTAssertEqual(second.externalId, "user_9")

        try await second.tag(["returning"])
        XCTAssertEqual(jsonBody(transport.requests[0])["token"] as? String, tokenHex)
    }

    func testResetForgetsTokenAndExternalId() async throws {
        let defaults = makeDefaults()
        let client = makeClient(MockTransport(), defaults: defaults)
        try await client.identify("user_3")
        client.setAPNsToken(tokenData)
        await client.waitForPendingRegistration()

        client.reset()

        XCTAssertNil(client.apnsToken)
        XCTAssertNil(client.externalId)
        XCTAssertNil(ReachBell(userDefaults: defaults, transport: MockTransport()).apnsToken)
    }
}

private final class ResultBox: Sendable {
    private let stored = Locked<Result<Void, ReachBellError>?>(nil)

    var value: Result<Void, ReachBellError>? {
        stored.read { $0 }
    }

    func set(_ result: Result<Void, ReachBellError>) {
        stored.mutate { $0 = result }
    }
}
