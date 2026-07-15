//
//  AccessToken2.swift
//  VoiceAgent
//
//  Swift AccessToken2 implementation aligned with the Kotlin demo's Java builder.
//

import Compression
import CryptoKit
import Foundation

final class AccessToken2 {
    enum PrivilegeRtc: UInt16 {
        case joinChannel = 1
        case publishAudioStream = 2
        case publishVideoStream = 3
        case publishDataStream = 4
    }

    enum PrivilegeRtm: UInt16 {
        case login = 1
    }

    private static let version = "007"
    private static let serviceTypeRTC: UInt16 = 1
    private static let serviceTypeRTM: UInt16 = 2

    private let appCertificate: String
    private let appId: String
    private let expire: UInt32
    private let issueTs: UInt32
    private let salt: UInt32
    private var services: [UInt16: Service] = [:]

    init(appId: String, appCertificate: String, expire: UInt32) {
        self.appId = appId
        self.appCertificate = appCertificate
        self.expire = expire
        self.issueTs = UInt32(Date().timeIntervalSince1970)
        self.salt = UInt32.random(in: 1...99_999_999)
    }

    func addService(_ service: Service) {
        services[service.serviceType] = service
    }

    func build() throws -> String {
        guard Self.isUUID(appId), Self.isUUID(appCertificate) else {
            return ""
        }

        var signingInfo = TokenByteBuffer()
        signingInfo.putString(appId)
        signingInfo.putUInt32(issueTs)
        signingInfo.putUInt32(expire)
        signingInfo.putUInt32(salt)
        signingInfo.putUInt16(UInt16(services.count))

        let signing = Self.signing(
            appCertificate: appCertificate,
            issueTs: issueTs,
            salt: salt
        )

        for key in services.keys.sorted() {
            services[key]?.pack(into: &signingInfo)
        }

        let signature = Self.hmacSha256(key: signing, data: Array(signingInfo.data))

        var tokenPayload = TokenByteBuffer()
        tokenPayload.putBytes(signature)
        tokenPayload.append(signingInfo.data)

        let compressedPayload = try Zlib.deflate(tokenPayload.data)
        return Self.version + compressedPayload.base64EncodedString()
    }

    static func getUidStr(_ uid: UInt32) -> String {
        uid == 0 ? "" : String(uid)
    }

    private static func signing(
        appCertificate: String,
        issueTs: UInt32,
        salt: UInt32
    ) -> [UInt8] {
        let signingKey = hmacSha256(
            key: Array(TokenByteBuffer.uint32Data(issueTs)),
            data: Array(appCertificate.utf8)
        )
        return hmacSha256(
            key: Array(TokenByteBuffer.uint32Data(salt)),
            data: signingKey
        )
    }

    private static func hmacSha256(key: [UInt8], data: [UInt8]) -> [UInt8] {
        let key = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Array(mac)
    }

    private static func isUUID(_ value: String) -> Bool {
        guard value.count == 32 else { return false }
        return value.allSatisfy { $0.isHexDigit }
    }
}

extension AccessToken2 {
    class Service {
        let serviceType: UInt16
        private var privileges: [UInt16: UInt32] = [:]

        init(serviceType: UInt16) {
            self.serviceType = serviceType
        }

        func addPrivilegeRtc(_ privilege: PrivilegeRtc, expire: UInt32) {
            privileges[privilege.rawValue] = expire
        }

        func addPrivilegeRtm(_ privilege: PrivilegeRtm, expire: UInt32) {
            privileges[privilege.rawValue] = expire
        }

        func pack(into buffer: inout TokenByteBuffer) {
            buffer.putUInt16(serviceType)
            buffer.putUInt32Map(privileges)
        }
    }

    final class ServiceRtc: Service {
        private let channelName: String
        private let uid: String

        init(channelName: String, uid: String) {
            self.channelName = channelName
            self.uid = uid
            super.init(serviceType: AccessToken2.serviceTypeRTC)
        }

        override func pack(into buffer: inout TokenByteBuffer) {
            super.pack(into: &buffer)
            buffer.putString(channelName)
            buffer.putString(uid)
        }
    }

    final class ServiceRtm: Service {
        private let userId: String

        init(userId: String) {
            self.userId = userId
            super.init(serviceType: AccessToken2.serviceTypeRTM)
        }

        override func pack(into buffer: inout TokenByteBuffer) {
            super.pack(into: &buffer)
            buffer.putString(userId)
        }
    }
}

struct TokenByteBuffer {
    private(set) var data = Data()

    mutating func append(_ value: Data) {
        data.append(value)
    }

    mutating func putUInt16(_ value: UInt16) {
        data.append(Self.uint16Data(value))
    }

    mutating func putUInt32(_ value: UInt32) {
        data.append(Self.uint32Data(value))
    }

    mutating func putString(_ value: String) {
        putBytes(Array(value.utf8))
    }

    mutating func putBytes(_ value: [UInt8]) {
        putUInt16(UInt16(value.count))
        data.append(contentsOf: value)
    }

    mutating func putUInt32Map(_ value: [UInt16: UInt32]) {
        putUInt16(UInt16(value.count))
        for key in value.keys.sorted() {
            guard let mapValue = value[key] else { continue }
            putUInt16(key)
            putUInt32(mapValue)
        }
    }

    static func uint16Data(_ value: UInt16) -> Data {
        Data([
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
        ])
    }

    static func uint32Data(_ value: UInt32) -> Data {
        Data([
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ])
    }

    static func uint32BigEndianData(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ])
    }
}

private enum Zlib {
    static func deflate(_ data: Data) throws -> Data {
        let rawDeflated = try rawDeflate(data)
        var zlibData = Data([0x78, 0x9C])
        zlibData.append(rawDeflated)
        zlibData.append(TokenByteBuffer.uint32BigEndianData(adler32(data)))
        return zlibData
    }

    private static func rawDeflate(_ data: Data) throws -> Data {
        let sourceBytes = Array(data)
        var destinationBuffer = [UInt8](repeating: 0, count: max(data.count, 1) + 16)

        while true {
            let compressedSize = data.withUnsafeBytes { sourcePointer -> Int in
                guard let source = sourcePointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }

                return compression_encode_buffer(
                    &destinationBuffer,
                    destinationBuffer.count,
                    source,
                    sourceBytes.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }

            if compressedSize > 0 {
                return Data(destinationBuffer[0..<compressedSize])
            }

            if destinationBuffer.count > sourceBytes.count * 20 {
                throw AccessToken2Error.deflateFailed
            }

            destinationBuffer = [UInt8](repeating: 0, count: destinationBuffer.count * 2)
        }
    }

    private static func adler32(_ data: Data) -> UInt32 {
        let modulus: UInt32 = 65_521
        var a: UInt32 = 1
        var b: UInt32 = 0

        for byte in data {
            a = (a + UInt32(byte)) % modulus
            b = (b + a) % modulus
        }

        return (b << 16) | a
    }
}

private enum AccessToken2Error: Error {
    case deflateFailed
}
