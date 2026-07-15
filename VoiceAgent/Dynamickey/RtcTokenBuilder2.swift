//
//  RtcTokenBuilder2.swift
//  VoiceAgent
//
//  Minimal RTC + RTM AccessToken2 builder used by the demo TokenGenerator.
//

import Foundation

final class RtcTokenBuilder2 {
    enum Role {
        case publisher
        case subscriber
    }

    func buildTokenWithRtm(
        appId: String,
        appCertificate: String,
        channelName: String,
        account: String,
        role: Role,
        tokenExpire: Int,
        privilegeExpire: Int
    ) throws -> String {
        let tokenExpire = UInt32(tokenExpire)
        let privilegeExpire = UInt32(privilegeExpire)
        let accessToken = AccessToken2(
            appId: appId,
            appCertificate: appCertificate,
            expire: tokenExpire
        )

        let serviceRtc = AccessToken2.ServiceRtc(channelName: channelName, uid: account)
        serviceRtc.addPrivilegeRtc(.joinChannel, expire: privilegeExpire)
        if role == .publisher {
            serviceRtc.addPrivilegeRtc(.publishAudioStream, expire: privilegeExpire)
            serviceRtc.addPrivilegeRtc(.publishVideoStream, expire: privilegeExpire)
            serviceRtc.addPrivilegeRtc(.publishDataStream, expire: privilegeExpire)
        }
        accessToken.addService(serviceRtc)

        let serviceRtm = AccessToken2.ServiceRtm(userId: account)
        serviceRtm.addPrivilegeRtm(.login, expire: tokenExpire)
        accessToken.addService(serviceRtm)

        return try accessToken.build()
    }
}
