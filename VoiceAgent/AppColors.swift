//
//  AppColors.swift
//  VoiceAgent
//

import UIKit

enum AppColors {
    // MARK: - Background
    static let bgPrimary = UIColor(hex: 0x0F172A)
    static let bgSecondary = UIColor(hex: 0x1E293B)
    static let bgTertiary = UIColor(hex: 0x334155)
    static let bgCard = UIColor(hex: 0x1E293B, alpha: 0.5)
    static let bgControlBar = UIColor(hex: 0x1E293B, alpha: 0.8)
    static let bgLogContent = UIColor(hex: 0x020617, alpha: 0.5)
    static let borderDefault = UIColor(hex: 0x334155, alpha: 0.5)

    // MARK: - Text
    static let textPrimary = UIColor(hex: 0xF8FAFC)
    static let textTitle = UIColor.white
    static let textSubtitle = UIColor(hex: 0xCBD5E1)
    static let textSecondary = UIColor(hex: 0x94A3B8)
    static let textTertiary = UIColor(hex: 0x64748B)
    static let textWeak = UIColor(hex: 0x475569)

    // MARK: - Accent / Functional
    static let accentBlue = UIColor(hex: 0x3B82F6)
    static let accentBlueDark = UIColor(hex: 0x2563EB)
    static let successGreen = UIColor(hex: 0x22C55E)
    static let successGreenLight = UIColor(hex: 0x34D399)
    static let errorRed = UIColor(hex: 0xEF4444)
    static let errorRedDark = UIColor(hex: 0xDC2626)
    static let errorRedLight = UIColor(hex: 0xF87171)
    static let warningAmber = UIColor(hex: 0xF59E0B)
    static let warningAmberLight = UIColor(hex: 0xFBBF24)

    // MARK: - Agent State
    static let stateIdle = UIColor(hex: 0x64748B)
    static let stateListening = UIColor(hex: 0x10B981)
    static let stateThinking = UIColor(hex: 0xF59E0B)
    static let stateSpeaking = UIColor(hex: 0x3B82F6)
    static let stateSilent = UIColor(hex: 0x475569)

    // MARK: - Chat Bubble
    static let avatarAgent = UIColor(hex: 0x3B82F6)
    static let avatarUser = UIColor(hex: 0x10B981)
    static let bubbleAgentBg = UIColor(hex: 0x334155)
    static let bubbleAgentText = UIColor(hex: 0xF1F5F9)
    static let bubbleUserBg = UIColor(hex: 0x2563EB)
    static let bubbleUserText = UIColor.white

    // MARK: - Buttons
    static let btnStartBg = UIColor(hex: 0x2563EB)
    static let btnStartPressed = UIColor(hex: 0x3B82F6)
    static let btnStopBg = UIColor(hex: 0xDC2626)
    static let btnStopPressed = UIColor(hex: 0xEF4444)
    static let btnDisabledBg = UIColor(hex: 0x334155)
    static let btnDisabledText = UIColor(hex: 0x94A3B8)

    // MARK: - Microphone
    static let micNormalBg = UIColor(hex: 0x334155)
    static let micNormalIcon = UIColor(hex: 0xCBD5E1)
    static let micMutedBg = UIColor(hex: 0xEF4444, alpha: 0.2)
    static let micMutedIcon = UIColor(hex: 0xF87171)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
