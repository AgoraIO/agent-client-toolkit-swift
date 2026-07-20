import Foundation

struct AgentBackendConfig: Decodable, Equatable {
    let appId: String
    let token: String
    let uid: String
    let agentUid: String
    let channelName: String

    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case token
        case uid
        case agentUid = "agent_uid"
        case channelName = "channel_name"
    }
}

struct StartAgentRequest: Codable, Equatable {
    let channelName: String
    let agentUid: Int
    let userUid: Int
    let startOfSpeechMode: String
    let endOfSpeechMode: String
}

struct StartAgentResult: Decodable, Equatable {
    let agentId: String
    let channelName: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case channelName = "channel_name"
        case status
    }
}

struct StopAgentRequest: Encodable, Equatable {
    let agentId: String
}

private struct BackendEnvelope<Payload: Decodable>: Decodable {
    let code: Int
    let data: Payload?
    let msg: String
}

private struct EmptyPayload: Decodable {}

enum AgentManagerError: LocalizedError {
    case invalidBackendURL(String)
    case backend(code: Int, message: String)
    case missingData(endpoint: String)
    case invalidData(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL(let value):
            return "Invalid AGENT_BACKEND_URL: \(value)"
        case .backend(let code, let message):
            return "Backend error \(code): \(message)"
        case .missingData(let endpoint):
            return "Backend response from \(endpoint) is missing data"
        case .invalidData(let message):
            return message
        }
    }
}

final class AgentManager {
    let baseURL: URL
    private let networkManager: NetworkManager

    init(baseURLString: String, networkManager: NetworkManager = NetworkManager()) throws {
        let normalized = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw AgentManagerError.invalidBackendURL(baseURLString)
        }
        self.baseURL = url
        self.networkManager = networkManager
    }

    func getConfiguration(channel: String? = nil, uid: Int? = nil) async throws -> AgentBackendConfig {
        var queryItems: [URLQueryItem] = []
        if let channel, !channel.isEmpty {
            queryItems.append(URLQueryItem(name: "channel", value: channel))
        }
        if let uid {
            queryItems.append(URLQueryItem(name: "uid", value: String(uid)))
        }
        let response: BackendEnvelope<AgentBackendConfig> = try await networkManager.get(
            url: endpoint("get_config"),
            queryItems: queryItems
        )
        return try payload(from: response, endpoint: "/get_config")
    }

    func startAgent(_ request: StartAgentRequest) async throws -> StartAgentResult {
        let response: BackendEnvelope<StartAgentResult> = try await networkManager.post(
            url: endpoint("startAgent"),
            body: request
        )
        let result = try payload(from: response, endpoint: "/startAgent")
        guard !result.agentId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentManagerError.invalidData(message: "Backend returned an empty agentId")
        }
        return result
    }

    func stopAgent(agentId: String) async throws {
        let response: BackendEnvelope<EmptyPayload> = try await networkManager.post(
            url: endpoint("stopAgent"),
            body: StopAgentRequest(agentId: agentId)
        )
        guard response.code == 0 else {
            throw AgentManagerError.backend(code: response.code, message: response.msg)
        }
    }

    private func endpoint(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private func payload<Payload: Decodable>(
        from response: BackendEnvelope<Payload>,
        endpoint: String
    ) throws -> Payload {
        guard response.code == 0 else {
            throw AgentManagerError.backend(code: response.code, message: response.msg)
        }
        guard let data = response.data else {
            throw AgentManagerError.missingData(endpoint: endpoint)
        }
        return data
    }
}
