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
    private let controlBarView = UIStackView()
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
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        tableView.register(TranscriptMessageCell.self, forCellReuseIdentifier: TranscriptMessageCell.reuseIdentifier)
        transcriptCardView.addSubview(tableView)

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

        endCallButton.setTitle("Stop Agent", for: .normal)
        endCallButton.setTitleColor(.white, for: .normal)
        endCallButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        endCallButton.backgroundColor = AppColors.btnStopBg
        endCallButton.layer.cornerRadius = 8
        endCallButton.clipsToBounds = true
        controlBarView.addArrangedSubview(endCallButton)
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

        tableView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
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

    // UIKit may reset the table background color to a system dynamic color during layout.
    // Apply it from the parent controller after the table has been attached to the final view hierarchy.
    func applyTableBackgroundWorkaround() {
        tableView.backgroundColor = .clear
    }
}
