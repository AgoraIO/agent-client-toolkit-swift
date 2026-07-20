import Foundation

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@discardableResult
private func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

private func jsonData(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

private func requestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 {
            break
        }
        data.append(buffer, count: count)
    }
    return data
}

private func makeManager(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) throws -> AgentManager {
    MockURLProtocol.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let networkManager = NetworkManager(session: URLSession(configuration: configuration))
    return try AgentManager(
        baseURLString: "http://192.168.1.20:8001/",
        networkManager: networkManager
    )
}

private func response(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )!
}

private func testGetConfigURLAndDecoding() async throws {
    var capturedRequest: URLRequest?
    let manager = try makeManager { request in
        capturedRequest = request
        return (
            response(for: request),
            jsonData([
                "code": 0,
                "data": [
                    "app_id": "app-id",
                    "token": "007-token",
                    "uid": "1001",
                    "agent_uid": "10000001",
                    "channel_name": "channel_swift_123456"
                ],
                "msg": "success"
            ])
        )
    }

    let config = try await manager.getConfiguration(
        channel: "channel_swift_123456",
        uid: 1001
    )

    expect(config.appId == "app-id", "app_id should decode")
    expect(config.agentUid == "10000001", "agent_uid should decode")
    let components = URLComponents(url: capturedRequest!.url!, resolvingAgainstBaseURL: false)
    let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    expect(capturedRequest?.httpMethod == "GET", "get_config should use GET")
    expect(capturedRequest?.url?.path == "/get_config", "get_config path should be appended once")
    expect(capturedRequest?.cachePolicy == .reloadIgnoringLocalCacheData, "get_config should bypass URLCache")
    expect(query["channel"] == "channel_swift_123456", "channel should use URLQueryItem")
    expect(query["uid"] == "1001", "uid should use URLQueryItem")
}

private func testStartAndStopBodies() async throws {
    var bodies: [[String: Any]] = []
    let manager = try makeManager { request in
        guard let body = requestBodyData(request) else {
            throw URLError(.cannotDecodeContentData)
        }
        bodies.append(try JSONSerialization.jsonObject(with: body) as! [String: Any])
        if request.url?.path == "/startAgent" {
            return (
                response(for: request),
                jsonData([
                    "code": 0,
                    "data": [
                        "agent_id": "agent-id",
                        "channel_name": "channel-1",
                        "status": "started"
                    ],
                    "msg": "success"
                ])
            )
        }
        return (
            response(for: request),
            jsonData(["code": 0, "data": NSNull(), "msg": "success"])
        )
    }

    let result = try await manager.startAgent(
        StartAgentRequest(
            channelName: "channel-1",
            agentUid: 10_000_001,
            userUid: 1001,
            startOfSpeechMode: "manual",
            endOfSpeechMode: "semantic"
        )
    )
    try await manager.stopAgent(agentId: result.agentId)

    expect(result.agentId == "agent-id", "start response should decode agent_id")
    expect(bodies.count == 2, "start and stop should both send JSON bodies")
    expect(bodies[0]["channelName"] as? String == "channel-1", "start body should use channelName")
    expect(bodies[0]["agentUid"] as? Int == 10_000_001, "start body should use agentUid")
    expect(bodies[0]["startOfSpeechMode"] as? String == "manual", "start body should carry SOS mode")
    expect(bodies[0]["endOfSpeechMode"] as? String == "semantic", "start body should carry EOS mode")
    expect(bodies[1] as NSDictionary == ["agentId": "agent-id"] as NSDictionary, "stop body should only carry agentId")
}

private func testHTTPAndEnvelopeErrors() async throws {
    let httpManager = try makeManager { request in
        (
            response(for: request, statusCode: 422),
            jsonData(["code": 4220, "data": NSNull(), "msg": "Invalid request: bad mode"])
        )
    }
    do {
        _ = try await httpManager.getConfiguration()
        expect(false, "non-2xx response should fail")
    } catch {
        expect(error.localizedDescription.contains("HTTP 422"), "HTTP error should include status")
        expect(error.localizedDescription.contains("bad mode"), "HTTP error should preserve backend message")
        expect(error.localizedDescription.contains("192.168.1.20"), "HTTP error should include attempted URL")
    }

    let envelopeManager = try makeManager { request in
        (
            response(for: request),
            jsonData(["code": 9001, "data": NSNull(), "msg": "backend rejected request"])
        )
    }
    do {
        _ = try await envelopeManager.getConfiguration()
        expect(false, "non-zero envelope code should fail")
    } catch {
        expect(error.localizedDescription.contains("9001"), "envelope error should include code")
        expect(error.localizedDescription.contains("backend rejected request"), "envelope error should include message")
    }
}

private func testMalformedAndTransportErrors() async throws {
    let malformedManager = try makeManager { request in
        (response(for: request), Data("not-json".utf8))
    }
    do {
        _ = try await malformedManager.getConfiguration()
        expect(false, "malformed response should fail")
    } catch {
        expect(error.localizedDescription.contains("invalid response"), "malformed response should be actionable")
    }

    let transportManager = try makeManager { _ in
        throw URLError(.notConnectedToInternet)
    }
    do {
        _ = try await transportManager.getConfiguration()
        expect(false, "transport error should fail")
    } catch {
        expect(error.localizedDescription.contains("Cannot reach backend"), "transport error should identify reachability")
        expect(error.localizedDescription.contains("192.168.1.20"), "transport error should include attempted URL")
    }
}

@main
private struct BackendClientTests {
    static func main() async {
        do {
            try await testGetConfigURLAndDecoding()
            try await testStartAndStopBodies()
            try await testHTTPAndEnvelopeErrors()
            try await testMalformedAndTransportErrors()
            print("BackendClientTests passed")
        } catch {
            fputs("FAIL: unexpected error: \(error)\n", stderr)
            exit(1)
        }
    }
}
