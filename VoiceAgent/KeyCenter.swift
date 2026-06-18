//
//  KeyCenter.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation

class KeyCenter {
    static let AG_APP_ID: String = value(for: "AGORA_APP_ID")
    static let AG_APP_CERTIFICATE: String = value(for: "AGORA_APP_CERTIFICATE")

    static var missingRequiredKeys: [String] {
        [
            ("AGORA_APP_ID", AG_APP_ID),
            ("AGORA_APP_CERTIFICATE", AG_APP_CERTIFICATE)
        ].compactMap { key, value in
            value.isEmpty ? key : nil
        }
    }

    static var isConfigured: Bool {
        missingRequiredKeys.isEmpty
    }

    private static func value(for key: String) -> String {
        if let value = validValue(Bundle.main.object(forInfoDictionaryKey: key) as? String) {
            return value
        }

        if let value = validValue(secretsPlist[key] as? String) {
            return value
        }

        return ""
    }

    private static func validValue(_ rawValue: String?) -> String? {
        guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.hasPrefix("$(") else {
            return nil
        }

        if value == "your_app_id" || value == "your_app_certificate" {
            return nil
        }

        return value
    }

    private static let secretsPlist: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any] else {
            return [:]
        }
        return dictionary
    }()
}
