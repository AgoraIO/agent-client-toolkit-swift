//
//  TranscriptMessageCell.swift
//  VoiceAgent
//

import UIKit
import SnapKit
import AgoraAgentClientToolkit

struct TurnLatencyMetrics: Equatable {
    let turnId: Int
    let e2eLatencyMs: Int?
    let transportLatencyMs: Int?
    let algorithmProcessingLatencyMs: Int?
    let asrLatencyMs: Int?
    let llmLatencyMs: Int?
    let ttsLatencyMs: Int?
}

struct TranscriptItem: Equatable {
    var transcript: Transcript
    var latencyMetrics: TurnLatencyMetrics?

    static func == (lhs: TranscriptItem, rhs: TranscriptItem) -> Bool {
        lhs.transcript.turnId == rhs.transcript.turnId &&
            lhs.transcript.userId == rhs.transcript.userId &&
            lhs.transcript.text == rhs.transcript.text &&
            lhs.transcript.status == rhs.transcript.status &&
            lhs.transcript.type == rhs.transcript.type &&
            lhs.latencyMetrics == rhs.latencyMetrics
    }
}

private extension Optional where Wrapped == Int {
    var latencyText: String {
        map { "\($0)ms" } ?? "--"
    }
}

class TranscriptMessageCell: UITableViewCell {
    static let reuseIdentifier = "TranscriptMessageCell"

    private let speakerRowView = UIStackView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let speakerNameLabel = UILabel()
    private let messageLabel = UILabel()
    private let latencyContainerView = UIView()
    private let latencyTurnLabel = UILabel()
    private let latencySummaryLabel = UILabel()

    private var latencyTop: Constraint?
    private var latencyHeight: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        speakerRowView.axis = .horizontal
        speakerRowView.alignment = .center
        speakerRowView.distribution = .fill
        speakerRowView.spacing = 6
        contentView.addSubview(speakerRowView)

        avatarView.layer.cornerRadius = 11
        avatarView.clipsToBounds = true
        speakerRowView.addArrangedSubview(avatarView)

        avatarLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)

        speakerNameLabel.font = .systemFont(ofSize: 13, weight: .bold)
        speakerNameLabel.textColor = AppColors.textSubtitle
        speakerNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        speakerRowView.addArrangedSubview(speakerNameLabel)

        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.numberOfLines = 0
        contentView.addSubview(messageLabel)

        latencyContainerView.isHidden = true
        contentView.addSubview(latencyContainerView)

        latencyTurnLabel.font = .systemFont(ofSize: 10, weight: .medium)
        latencyTurnLabel.textColor = AppColors.textSecondary
        latencyTurnLabel.backgroundColor = AppColors.bgTertiary
        latencyTurnLabel.layer.cornerRadius = 4
        latencyTurnLabel.clipsToBounds = true
        latencyTurnLabel.textAlignment = .center
        latencyContainerView.addSubview(latencyTurnLabel)

        latencySummaryLabel.font = .systemFont(ofSize: 10, weight: .regular)
        latencySummaryLabel.textColor = AppColors.textTertiary
        latencySummaryLabel.numberOfLines = 2
        latencyContainerView.addSubview(latencySummaryLabel)

        speakerRowView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.left.right.equalToSuperview().inset(4)
            make.height.equalTo(24)
        }

        avatarView.snp.makeConstraints { make in
            make.width.height.equalTo(22)
        }

        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(speakerRowView.snp.bottom).offset(4)
            make.left.right.equalToSuperview().inset(4)
        }

        latencyContainerView.snp.makeConstraints { make in
            latencyTop = make.top.equalTo(messageLabel.snp.bottom).offset(0).constraint
            make.left.right.equalToSuperview().inset(4)
            make.bottom.equalToSuperview().offset(-6)
            latencyHeight = make.height.equalTo(0).constraint
        }

        latencyTurnLabel.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.height.equalTo(16)
            make.width.greaterThanOrEqualTo(22)
        }

        latencySummaryLabel.snp.makeConstraints { make in
            make.left.equalTo(latencyTurnLabel.snp.right).offset(6)
            make.right.centerY.equalToSuperview()
        }
    }

    func configure(
        with transcript: Transcript,
        latencyMetrics: TurnLatencyMetrics?,
        isLatencyMetricsVisible: Bool
    ) {
        let isAgent = transcript.type == .agent

        avatarView.backgroundColor = isAgent ? AppColors.avatarAgent : AppColors.avatarUser
        avatarLabel.text = isAgent ? "AI" : "Me"
        speakerNameLabel.text = isAgent ? "Assistant" : "Me"
        speakerNameLabel.textAlignment = isAgent ? .left : .right
        messageLabel.textAlignment = isAgent ? .left : .right
        messageLabel.textColor = isAgent ? AppColors.bubbleAgentText : AppColors.bubbleUserText
        messageLabel.text = transcript.text.isEmpty ? "..." : transcript.text

        speakerRowView.semanticContentAttribute = isAgent ? .forceLeftToRight : .forceRightToLeft
        configureLatencyMetrics(latencyMetrics, isVisible: isAgent && isLatencyMetricsVisible)
    }

    private func configureLatencyMetrics(_ metrics: TurnLatencyMetrics?, isVisible: Bool) {
        let shouldShow = isVisible && metrics != nil
        latencyContainerView.isHidden = !shouldShow
        latencyTop?.update(offset: shouldShow ? 5 : 0)
        latencyHeight?.update(offset: shouldShow ? 34 : 0)

        guard let metrics else {
            latencyTurnLabel.text = nil
            latencySummaryLabel.text = nil
            return
        }

        latencyTurnLabel.text = "#\(metrics.turnId)"
        latencySummaryLabel.text = buildLatencySummary(metrics)
    }

    private func buildLatencySummary(_ metrics: TurnLatencyMetrics) -> String {
        [
            "E2E:\(metrics.e2eLatencyMs.latencyText)",
            "RTC:\(metrics.transportLatencyMs.latencyText)",
            "AI:\(metrics.algorithmProcessingLatencyMs.latencyText)",
            "ASR:\(metrics.asrLatencyMs.latencyText)",
            "LLM:\(metrics.llmLatencyMs.latencyText)",
            "TTS:\(metrics.ttsLatencyMs.latencyText)"
        ].joined(separator: "  ")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        speakerRowView.semanticContentAttribute = .unspecified
        messageLabel.textAlignment = .left
        speakerNameLabel.textAlignment = .left
        configureLatencyMetrics(nil, isVisible: false)
    }
}
