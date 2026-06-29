//
//  ConfigBackgroundView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class ConnectionStartView: UIView {
    enum State {
        case ready
        case connecting
    }

    // MARK: - UI Components
    let startButton = UIButton(type: .system)

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear

        startButton.setTitle("Start Agent", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(AppColors.btnDisabledText, for: .disabled)
        startButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        startButton.backgroundColor = AppColors.btnStartBg
        startButton.layer.cornerRadius = 8
        startButton.isEnabled = true
        addSubview(startButton)
    }

    private func setupConstraints() {
        startButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Public Methods
    func updateButtonState(isEnabled: Bool) {
        startButton.isEnabled = isEnabled
        startButton.backgroundColor = isEnabled ? AppColors.btnStartBg : AppColors.btnDisabledBg
    }

    func update(for state: State) {
        switch state {
        case .ready:
            startButton.setTitle("Start Agent", for: .normal)
            startButton.setTitleColor(.white, for: .normal)
            updateButtonState(isEnabled: true)
        case .connecting:
            startButton.setTitle("Connecting...", for: .normal)
            startButton.setTitleColor(AppColors.btnDisabledText, for: .normal)
            updateButtonState(isEnabled: false)
        }
    }
}
