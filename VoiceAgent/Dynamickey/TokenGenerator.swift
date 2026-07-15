//
//  TokenGenerator.swift
//  VoiceAgent
//
//  Demo-only local RTC + RTM token generation.
//

import Foundation

enum TokenGenerator {
    private static let defaultExpireSeconds = 60 * 60 * 24

    static func generateTokensAsync(
        channelName: String,
        uid: String
    ) async -> Result<String, Error> {
        do {
            let token = try await fetchToken(channelName: channelName, uid: uid)
            return .success(token)
        } catch {
            return .failure(error)
        }
    }

    private static func fetchToken(
        channelName: String,
        uid: String
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try generateLocalConvoAiToken(
                appId: KeyCenter.APP_ID,
                appCertificate: KeyCenter.APP_CERTIFICATE,
                channelName: channelName,
                uid: uid
            )
        }.value
    }

    private static func generateLocalConvoAiToken(
        appId: String,
        appCertificate: String,
        channelName: String,
        uid: String
    ) throws -> String {
        guard !appCertificate.isEmpty else {
            throw TokenGeneratorError.missingAppCertificate
        }

        guard !uid.isEmpty, uid.allSatisfy({ $0.isNumber }) else {
            throw TokenGeneratorError.invalidUid
        }

        let tokenExpire = defaultExpireSeconds
        let token = try RtcTokenBuilder2().buildTokenWithRtm(
            appId: appId,
            appCertificate: appCertificate,
            channelName: channelName,
            account: uid,
            role: .publisher,
            tokenExpire: tokenExpire,
            privilegeExpire: tokenExpire
        )

        guard !token.isEmpty else {
            throw TokenGeneratorError.failedToGenerate
        }

        return token
    }
}

private enum TokenGeneratorError: LocalizedError {
    case missingAppCertificate
    case invalidUid
    case failedToGenerate

    var errorDescription: String? {
        switch self {
        case .missingAppCertificate:
            return "APP_CERTIFICATE is required for local ConvoAI token generation"
        case .invalidUid:
            return "uid must be numeric when auto-generating a ConvoAI token"
        case .failedToGenerate:
            return "Failed to generate ConvoAI token with AccessToken2 implementation"
        }
    }
}
