//
//  KeyCenter.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation

class KeyCenter {
    static let APP_ID: String = value(for: "APP_ID")
    static let APP_CERTIFICATE: String = value(for: "APP_CERTIFICATE")
    static let LLM_URL: String = value(for: "LLM_URL", defaultValue: "https://api.groq.com/openai/v1/chat/completions")
    static let LLM_API_KEY: String = value(for: "LLM_API_KEY")
    static let LLM_MODEL: String = value(for: "LLM_MODEL", defaultValue: "llama-3.3-70b-versatile")
    static let TTS_VENDOR: String = value(for: "TTS_VENDOR", defaultValue: "elevenlabs")
    static let TTS_KEY: String = value(for: "TTS_KEY")
    static let TTS_MODEL_ID: String = value(for: "TTS_MODEL_ID", defaultValue: "eleven_flash_v2_5")
    static let TTS_VOICE_ID: String = value(for: "TTS_VOICE_ID")
    static let TTS_SAMPLE_RATE: Int = intValue(for: "TTS_SAMPLE_RATE", defaultValue: 44100)

    static var missingRequiredKeys: [String] {
        [
            ("APP_ID", APP_ID),
            ("APP_CERTIFICATE", APP_CERTIFICATE)
        ].compactMap { key, value in
            value.isEmpty ? key : nil
        }
    }

    private static func value(for key: String, defaultValue: String = "") -> String {
        if let value = validValue(Bundle.main.object(forInfoDictionaryKey: key) as? String) {
            return value
        }

        if let value = validValue(secretsPlist[key] as? String) {
            return value
        }

        return defaultValue
    }

    private static func intValue(for key: String, defaultValue: Int) -> Int {
        if let value = Int(value(for: key)) {
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

        if [
            "your_app_id",
            "your_agora_app_id",
            "your_agora_app_certificate"
        ].contains(value) {
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
