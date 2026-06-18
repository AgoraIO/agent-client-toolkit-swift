//
//  TranscriptMessageCell.swift
//  VoiceAgent
//

import UIKit
import SnapKit
import AgoraAgentClientToolkit

class TranscriptMessageCell: UITableViewCell {
    static let reuseIdentifier = "TranscriptMessageCell"

    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    private var bubbleLeading: Constraint?
    private var bubbleTrailing: Constraint?
    private var avatarLeading: Constraint?
    private var avatarTrailing: Constraint?

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

        avatarView.layer.cornerRadius = 16
        contentView.addSubview(avatarView)

        avatarLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)

        bubbleView.layer.cornerRadius = 16
        contentView.addSubview(bubbleView)

        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.numberOfLines = 0
        bubbleView.addSubview(messageLabel)

        avatarView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.width.height.equalTo(32)
            avatarLeading = make.left.equalToSuperview().offset(12).constraint
            avatarTrailing = make.right.equalToSuperview().offset(-12).constraint
        }
        avatarTrailing?.deactivate()

        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        bubbleView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(-4)
            make.width.lessThanOrEqualToSuperview().multipliedBy(0.78)
            bubbleLeading = make.left.equalTo(avatarView.snp.right).offset(8).constraint
            bubbleTrailing = make.right.equalTo(avatarView.snp.left).offset(-8).constraint
        }
        bubbleTrailing?.deactivate()

        messageLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        }
    }

    func configure(with transcript: Transcript) {
        let isAgent = transcript.type == .agent

        avatarView.backgroundColor = isAgent ? AppColors.avatarAgent : AppColors.avatarUser
        avatarLabel.text = isAgent ? "AI" : "Me"

        bubbleView.backgroundColor = isAgent ? AppColors.bubbleAgentBg : AppColors.bubbleUserBg
        messageLabel.textColor = isAgent ? AppColors.bubbleAgentText : AppColors.bubbleUserText
        messageLabel.text = transcript.text.isEmpty ? "..." : transcript.text

        if isAgent {
            avatarLeading?.activate()
            avatarTrailing?.deactivate()
            bubbleLeading?.activate()
            bubbleTrailing?.deactivate()
            bubbleView.semanticContentAttribute = .forceLeftToRight
        } else {
            avatarLeading?.deactivate()
            avatarTrailing?.activate()
            bubbleLeading?.deactivate()
            bubbleTrailing?.activate()
            bubbleView.semanticContentAttribute = .forceRightToLeft
        }

        let smallCorner: CGFloat = 2
        let bigCorner: CGFloat = 16
        if isAgent {
            applyBubbleCorners(topLeft: smallCorner, topRight: bigCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
        } else {
            applyBubbleCorners(topLeft: bigCorner, topRight: smallCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
        }
    }

    private func applyBubbleCorners(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        let path = UIBezierPath()
        bubbleView.layoutIfNeeded()
        let bounds = bubbleView.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 200, height: 40) : bubbleView.bounds

        path.move(to: CGPoint(x: topLeft, y: 0))
        path.addLine(to: CGPoint(x: bounds.width - topRight, y: 0))
        path.addArc(withCenter: CGPoint(x: bounds.width - topRight, y: topRight), radius: topRight, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - bottomRight))
        path.addArc(withCenter: CGPoint(x: bounds.width - bottomRight, y: bounds.height - bottomRight), radius: bottomRight, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: bottomLeft, y: bounds.height))
        path.addArc(withCenter: CGPoint(x: bottomLeft, y: bounds.height - bottomLeft), radius: bottomLeft, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        path.addArc(withCenter: CGPoint(x: topLeft, y: topLeft), radius: topLeft, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.close()

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        bubbleView.layer.mask = mask
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarLeading?.deactivate()
        avatarTrailing?.deactivate()
        bubbleLeading?.deactivate()
        bubbleTrailing?.deactivate()
        avatarLeading?.activate()
        bubbleLeading?.activate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let text = avatarLabel.text {
            let isAgent = text == "AI"
            let smallCorner: CGFloat = 2
            let bigCorner: CGFloat = 16
            if isAgent {
                applyBubbleCorners(topLeft: smallCorner, topRight: bigCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
            } else {
                applyBubbleCorners(topLeft: bigCorner, topRight: smallCorner, bottomLeft: bigCorner, bottomRight: bigCorner)
            }
        }
    }
}
