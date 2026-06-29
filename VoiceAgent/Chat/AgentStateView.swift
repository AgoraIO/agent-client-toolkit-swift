//
//  AgentStateView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit
import AgoraAgentClientToolkit

class AgentStateView: UIView {
    private let dotView = UIView()
    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear

        dotView.backgroundColor = AppColors.stateIdle
        dotView.layer.cornerRadius = 4
        addSubview(dotView)

        statusLabel.text = "Idle"
        statusLabel.textColor = AppColors.stateIdle
        statusLabel.font = .systemFont(ofSize: 13, weight: .bold)
        statusLabel.textAlignment = .left
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(statusLabel)
    }

    private func setupConstraints() {
        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(8)
            make.centerY.equalToSuperview()
            make.left.equalToSuperview()
        }

        statusLabel.snp.makeConstraints { make in
            make.left.equalTo(dotView.snp.right).offset(8)
            make.right.lessThanOrEqualToSuperview()
            make.centerY.equalToSuperview()
        }
    }

    func updateState(_ state: AgentState) {
        let (text, color): (String, UIColor) = {
            switch state {
            case .idle:     return ("Idle", AppColors.stateIdle)
            case .silent:   return ("Silent", AppColors.stateSilent)
            case .listening: return ("Listening", AppColors.stateListening)
            case .thinking: return ("Thinking", AppColors.stateThinking)
            case .speaking: return ("Speaking", AppColors.stateSpeaking)
            case .unknown:  return ("", AppColors.stateIdle)
            @unknown default: return ("", AppColors.stateIdle)
            }
        }()

        statusLabel.text = text
        statusLabel.textColor = color
        dotView.backgroundColor = color
    }
}
