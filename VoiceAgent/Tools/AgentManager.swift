//
//  AgentManager.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/10.
//

import Foundation

class AgentManager {
    static private var API_BASE_URL = "https://api.agora.io/api/conversational-ai-agent/v2/projects"

    static func startAgent(parameter: [String: Any], token: String, completion: ((String?, Error?) -> ())?) {
        let url = "\(API_BASE_URL)/\(KeyCenter.APP_ID)/join"
        let headers = generateHeader(token: token)
        
        NetworkManager.shared.postRequest(urlString: url, params: parameter, headers: headers) { response in
            if let agentId = response["agent_id"] as? String, !agentId.isEmpty {
                completion?(agentId, nil)
            } else {
                let errorMsg = "Failed to parse agent_id from response: \(response)"
                completion?(nil, NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        } failure: { error in
            completion?(nil, NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }
    }
    
    static func stopAgent(agentId: String, token: String, completion:((Error?)-> ())?) {
        let url = "\(API_BASE_URL)/\(KeyCenter.APP_ID)/agents/\(agentId)/leave"
        let header = generateHeader(token: token)
        NetworkManager.shared.postRequest(urlString: url, params: [:], headers: header) { res in
            completion?(nil)
        } failure: { error in
            completion?(NSError(domain: "stopAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }
    }
    
    static func generateHeader(token: String) -> [String: String] {
        let headers = [
            "Content-Type": "application/json; charset=utf-8",
            "Authorization": "agora token=\(token)"
        ]
        
        return headers
    }
}
