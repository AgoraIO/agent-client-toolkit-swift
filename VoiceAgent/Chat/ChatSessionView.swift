//
//  ChatBackgroundView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit
import AgoraAgentClientToolkit

class ChatSessionView: UIView {
    // MARK: - UI Components
    private let transcriptCardView = UIView()
    let tableView = UITableView()
    let statusView = AgentStateView()
    let realtimeDataToggleControl = UIControl()
    let realtimeDataSwitch = UISwitch()
    private let realtimeDataLabel = UILabel()
    private let interruptPanelView = UIView()
    private let capabilityPanelView = UIView()
    private let capabilityTitleLabel = UILabel()
    private let manualActionStackView = UIStackView()
    private let controlBarView = UIStackView()
    private var capabilityPanelHeightConstraint: Constraint?
    let manualSosButton = UIButton(type: .system)
    let manualEosButton = UIButton(type: .system)
    let interruptButton = UIButton(type: .system)
    let micButton = UIButton(type: .custom)
    let chatButton = UIButton(type: .custom)
    let endCallButton = UIButton(type: .custom)

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

        transcriptCardView.backgroundColor = .clear
        transcriptCardView.layer.cornerRadius = 0
        transcriptCardView.layer.borderWidth = 0
        transcriptCardView.clipsToBounds = false
        addSubview(transcriptCardView)

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = tableView.contentInset
        tableView.register(TranscriptMessageCell.self, forCellReuseIdentifier: TranscriptMessageCell.reuseIdentifier)
        transcriptCardView.addSubview(tableView)

        realtimeDataToggleControl.backgroundColor = AppColors.bgControlBar
        realtimeDataToggleControl.layer.cornerRadius = 12
        realtimeDataToggleControl.layer.borderWidth = 1
        realtimeDataToggleControl.layer.borderColor = AppColors.borderDefault.cgColor
        transcriptCardView.addSubview(realtimeDataToggleControl)

        realtimeDataLabel.text = "Real-time Data"
        realtimeDataLabel.textColor = AppColors.textSubtitle
        realtimeDataLabel.font = .systemFont(ofSize: 10, weight: .regular)
        realtimeDataLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        realtimeDataToggleControl.addSubview(realtimeDataLabel)

        realtimeDataSwitch.isOn = true
        realtimeDataSwitch.onTintColor = AppColors.accentBlue
        realtimeDataSwitch.thumbTintColor = .white
        realtimeDataSwitch.backgroundColor = AppColors.bgTertiary
        realtimeDataSwitch.layer.cornerRadius = 8
        realtimeDataSwitch.transform = CGAffineTransform(scaleX: 0.55, y: 0.55)
        realtimeDataToggleControl.addSubview(realtimeDataSwitch)

        capabilityPanelView.backgroundColor = AppColors.bgControlBar
        transcriptCardView.addSubview(capabilityPanelView)

        capabilityTitleLabel.text = "Capabilities"
        capabilityTitleLabel.textColor = AppColors.textSubtitle
        capabilityTitleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        capabilityPanelView.addSubview(capabilityTitleLabel)

        manualActionStackView.axis = .horizontal
        manualActionStackView.alignment = .fill
        manualActionStackView.distribution = .fillEqually
        manualActionStackView.spacing = 8
        capabilityPanelView.addSubview(manualActionStackView)

        configureManualButton(manualSosButton, title: "SOS")
        configureManualButton(manualEosButton, title: "EOS")
        manualActionStackView.addArrangedSubview(manualSosButton)
        manualActionStackView.addArrangedSubview(manualEosButton)
        capabilityPanelView.isHidden = true

        transcriptCardView.addSubview(statusView)
        transcriptCardView.addSubview(interruptPanelView)

        interruptPanelView.backgroundColor = .clear
        interruptPanelView.isHidden = true

        configureFloatingInterruptButton(interruptButton)
        interruptPanelView.addSubview(interruptButton)

        controlBarView.axis = .horizontal
        controlBarView.alignment = .center
        controlBarView.distribution = .equalSpacing
        controlBarView.spacing = 0
        controlBarView.layoutMargins = UIEdgeInsets(top: 8, left: 42, bottom: 8, right: 42)
        controlBarView.isLayoutMarginsRelativeArrangement = true
        addSubview(controlBarView)

        configureRoundControlButton(
            micButton,
            imageName: "mic.fill",
            tintColor: AppColors.micNormalIcon
        )
        controlBarView.addArrangedSubview(micButton)

        configureRoundControlButton(
            chatButton,
            imageName: "message",
            tintColor: .white
        )
        controlBarView.addArrangedSubview(chatButton)

        configureRoundControlButton(
            endCallButton,
            imageName: "xmark",
            tintColor: AppColors.errorRedLight
        )
        controlBarView.addArrangedSubview(endCallButton)
    }

    private func configureManualButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        button.backgroundColor = AppColors.btnManualBg
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func configureFloatingInterruptButton(_ button: UIButton) {
        button.setTitle("Interrupt", for: .normal)
        button.setTitleColor(AppColors.textSubtitle, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        button.backgroundColor = UIColor(hex: 0x334155, alpha: 0.6)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.borderDefault.cgColor
        button.clipsToBounds = true
    }

    private func configureRoundControlButton(_ button: UIButton, imageName: String, tintColor: UIColor) {
        button.setImage(UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = tintColor
        button.backgroundColor = AppColors.micNormalBg
        button.layer.cornerRadius = 32
        button.clipsToBounds = true
        button.imageView?.contentMode = .scaleAspectFit
    }

    private func setupConstraints() {
        controlBarView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(80)
        }

        micButton.snp.makeConstraints { make in
            make.width.height.equalTo(64)
        }

        chatButton.snp.makeConstraints { make in
            make.width.height.equalTo(64)
        }

        endCallButton.snp.makeConstraints { make in
            make.width.height.equalTo(64)
        }

        transcriptCardView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(controlBarView.snp.top).offset(-8)
        }

        capabilityPanelView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            capabilityPanelHeightConstraint = make.height.equalTo(0).constraint
        }

        capabilityTitleLabel.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview().inset(12)
        }

        manualActionStackView.snp.makeConstraints { make in
            make.top.equalTo(capabilityTitleLabel.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(12)
            make.height.equalTo(44)
        }

        realtimeDataToggleControl.snp.makeConstraints { make in
            make.centerY.equalTo(statusView)
            make.right.equalToSuperview().inset(4)
            make.height.equalTo(24)
        }

        realtimeDataLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
        }

        realtimeDataSwitch.snp.makeConstraints { make in
            make.left.equalTo(realtimeDataLabel.snp.right).offset(4)
            make.right.equalToSuperview().inset(2)
            make.centerY.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(statusView.snp.bottom).offset(2)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        statusView.snp.makeConstraints { make in
            make.top.equalTo(capabilityPanelView.snp.bottom).offset(2)
            make.left.equalToSuperview().offset(4)
            make.right.equalTo(realtimeDataToggleControl.snp.left).offset(-8)
            make.height.equalTo(36)
        }

        interruptPanelView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(58)
        }

        interruptButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(10)
            make.width.equalTo(128)
            make.height.equalTo(38)
        }
    }

    // MARK: - Public Methods
    func updateMicButtonState(isMuted: Bool) {
        let imageName = isMuted ? "mic.slash.fill" : "mic.fill"
        micButton.setImage(UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        micButton.tintColor = isMuted ? AppColors.micMutedIcon : AppColors.micNormalIcon
        micButton.backgroundColor = isMuted ? AppColors.micMutedBg : AppColors.micNormalBg
    }

    func updateStatusView(state: AgentState) {
        statusView.updateState(state)
    }

    func setControlsVisible(_ visible: Bool) {
        controlBarView.isHidden = !visible
        interruptPanelView.isHidden = !visible
        tableView.contentInset.bottom = visible ? 58 : 0
        tableView.scrollIndicatorInsets = tableView.contentInset
    }

    func updateManualActions(isManualSosEnabled: Bool, isManualEosEnabled: Bool, isConnected: Bool) {
        let shouldShowPanel = isConnected && (isManualSosEnabled || isManualEosEnabled)
        capabilityPanelView.isHidden = !shouldShowPanel
        capabilityPanelHeightConstraint?.update(offset: shouldShowPanel ? 92 : 0)
        manualSosButton.isHidden = !shouldShowPanel || !isManualSosEnabled
        manualEosButton.isHidden = !shouldShowPanel || !isManualEosEnabled
        manualSosButton.isEnabled = shouldShowPanel && isManualSosEnabled
        manualEosButton.isEnabled = shouldShowPanel && isManualEosEnabled
    }

    func setRealtimeDataVisible(_ visible: Bool) {
        if realtimeDataSwitch.isOn != visible {
            realtimeDataSwitch.setOn(visible, animated: false)
        }
    }

    // UIKit may reset the table background color to a system dynamic color during layout.
    // Apply it from the parent controller after the table has been attached to the final view hierarchy.
    func applyTableBackgroundWorkaround() {
        tableView.backgroundColor = .clear
    }
}
