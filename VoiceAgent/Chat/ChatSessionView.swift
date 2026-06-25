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
    private let capabilityPanelView = UIView()
    private let capabilityTitleLabel = UILabel()
    private let manualActionStackView = UIStackView()
    private let controlBarView = UIStackView()
    private var capabilityPanelHeightConstraint: Constraint?
    let manualSosButton = UIButton(type: .system)
    let manualEosButton = UIButton(type: .system)
    let micButton = UIButton(type: .custom)
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

        transcriptCardView.backgroundColor = AppColors.bgCard
        transcriptCardView.layer.cornerRadius = 12
        transcriptCardView.layer.borderWidth = 1
        transcriptCardView.layer.borderColor = AppColors.borderDefault.cgColor
        transcriptCardView.clipsToBounds = true
        addSubview(transcriptCardView)

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = tableView.contentInset
        tableView.register(TranscriptMessageCell.self, forCellReuseIdentifier: TranscriptMessageCell.reuseIdentifier)
        transcriptCardView.addSubview(tableView)

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

        controlBarView.axis = .horizontal
        controlBarView.alignment = .fill
        controlBarView.distribution = .fill
        controlBarView.spacing = 24
        addSubview(controlBarView)

        micButton.setImage(UIImage(systemName: "mic.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        micButton.tintColor = AppColors.micNormalIcon
        micButton.backgroundColor = AppColors.micNormalBg
        micButton.layer.cornerRadius = 28
        micButton.clipsToBounds = true
        controlBarView.addArrangedSubview(micButton)

        endCallButton.setTitle("Stop", for: .normal)
        endCallButton.setTitleColor(.white, for: .normal)
        endCallButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        endCallButton.backgroundColor = AppColors.btnStopBg
        endCallButton.layer.cornerRadius = 8
        endCallButton.clipsToBounds = true
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

    private func setupConstraints() {
        controlBarView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(56)
        }

        micButton.snp.makeConstraints { make in
            make.width.height.equalTo(56)
        }

        endCallButton.snp.makeConstraints { make in
            make.height.equalTo(56)
        }

        endCallButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        endCallButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        transcriptCardView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(controlBarView.snp.top).offset(-16)
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

        tableView.snp.makeConstraints { make in
            make.top.equalTo(capabilityPanelView.snp.bottom)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(statusView.snp.top)
        }

        statusView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(45)
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

    // UIKit may reset the table background color to a system dynamic color during layout.
    // Apply it from the parent controller after the table has been attached to the final view hierarchy.
    func applyTableBackgroundWorkaround() {
        tableView.backgroundColor = .clear
    }
}
