//
//  KeyCenter.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation

class KeyCenter {
    static let AGENT_BACKEND_URL: String = value(for: "AGENT_BACKEND_URL")

    static var missingRequiredKeys: [String] {
        AGENT_BACKEND_URL.isEmpty ? ["AGENT_BACKEND_URL"] : []
    }

    private static func value(for key: String, defaultValue: String = "") -> String {
        if let value = validValue(Bundle.main.object(forInfoDictionaryKey: key) as? String) {
            return value
        }
        return defaultValue
    }

    private static func validValue(_ rawValue: String?) -> String? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.hasPrefix("$(") else {
            return nil
        }

        if value.contains("<mac-lan-ip>") || value == "your_backend_url" {
            return nil
        }

        return value
    }
}
