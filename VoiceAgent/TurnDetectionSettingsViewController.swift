import UIKit
import SnapKit
import AgoraAgentClientToolkit

final class TurnDetectionSettingsViewController: UIViewController {
    private let titleLabel = UILabel()
    private let dividerTop = UIView()
    private let dividerAgentId = UIView()
    private let dividerMiddle = UIView()
    private let dividerBottom = UIView()
    private let versionLabel = UILabel()
    private let agentIdLabel = UILabel()
    private let agentIdValueLabel = UILabel()
    private let agentIdCopyButton = UIButton(type: .system)
    private let sosLabel = UILabel()
    private let eosLabel = UILabel()
    private let sosSegmentedControl = UISegmentedControl()
    private let eosSegmentedControl = UISegmentedControl()

    private let sosMode: TurnDetectionMode
    private let eosMode: TurnDetectionMode
    private let agentId: String
    private let canChangeTurnDetectionMode: Bool
    private let onSosModeChanged: (TurnDetectionMode) -> Void
    private let onEosModeChanged: (TurnDetectionMode) -> Void
    private let onCopyAgentId: () -> Bool

    init(
        sosMode: TurnDetectionMode,
        eosMode: TurnDetectionMode,
        agentId: String?,
        canChangeTurnDetectionMode: Bool,
        onSosModeChanged: @escaping (TurnDetectionMode) -> Void,
        onEosModeChanged: @escaping (TurnDetectionMode) -> Void,
        onCopyAgentId: @escaping () -> Bool
    ) {
        self.sosMode = sosMode
        self.eosMode = eosMode
        self.agentId = agentId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.canChangeTurnDetectionMode = canChangeTurnDetectionMode
        self.onSosModeChanged = onSosModeChanged
        self.onEosModeChanged = onEosModeChanged
        self.onCopyAgentId = onCopyAgentId
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSheetPresentation()
        setupUI()
        setupConstraints()
        applyInitialSelection()
    }

    private func setupSheetPresentation() {
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = [.medium()]
        sheet.selectedDetentIdentifier = .medium
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 16
    }

    private func setupUI() {
        view.backgroundColor = AppColors.bgSecondary

        titleLabel.text = "Settings"
        titleLabel.textColor = AppColors.textTitle
        titleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        view.addSubview(titleLabel)

        [dividerTop, dividerAgentId, dividerMiddle, dividerBottom].forEach { divider in
            divider.backgroundColor = AppColors.borderDefault
            view.addSubview(divider)
        }

        configureRowLabel(agentIdLabel, text: "Agent ID")
        agentIdLabel.textColor = AppColors.textPrimary
        configureRowLabel(sosLabel, text: "SOS")
        configureRowLabel(eosLabel, text: "EOS")
        view.addSubview(agentIdLabel)
        view.addSubview(sosLabel)
        view.addSubview(eosLabel)

        agentIdValueLabel.text = agentId
        agentIdValueLabel.textColor = AppColors.textSecondary
        agentIdValueLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        agentIdValueLabel.lineBreakMode = .byTruncatingMiddle
        agentIdValueLabel.numberOfLines = 1
        view.addSubview(agentIdValueLabel)

        agentIdCopyButton.setTitle("Copy", for: .normal)
        agentIdCopyButton.setTitleColor(AppColors.textSubtitle, for: .normal)
        agentIdCopyButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        agentIdCopyButton.backgroundColor = AppColors.bgControlBar
        agentIdCopyButton.layer.cornerRadius = 8
        agentIdCopyButton.layer.borderWidth = 1
        agentIdCopyButton.layer.borderColor = AppColors.borderDefault.cgColor
        agentIdCopyButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        agentIdCopyButton.isHidden = agentId.isEmpty
        view.addSubview(agentIdCopyButton)

        agentIdLabel.isHidden = agentId.isEmpty
        agentIdValueLabel.isHidden = agentId.isEmpty
        dividerAgentId.isHidden = agentId.isEmpty

        configureSegmentedControl(sosSegmentedControl)
        configureSegmentedControl(eosSegmentedControl)
        view.addSubview(sosSegmentedControl)
        view.addSubview(eosSegmentedControl)

        versionLabel.text = "Demo v\(demoVersion)  |  Component v\(ConversationalAIAPIImpl.version)"
        versionLabel.textColor = AppColors.textTertiary
        versionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        versionLabel.textAlignment = .left
        versionLabel.numberOfLines = 1
        versionLabel.adjustsFontSizeToFitWidth = true
        versionLabel.minimumScaleFactor = 0.85
        view.addSubview(versionLabel)

        agentIdCopyButton.addTarget(self, action: #selector(copyAgentIdButtonTapped), for: .touchUpInside)
        sosSegmentedControl.addTarget(self, action: #selector(sosSelectionChanged), for: .valueChanged)
        eosSegmentedControl.addTarget(self, action: #selector(eosSelectionChanged), for: .valueChanged)
    }

    private func configureRowLabel(_ label: UILabel, text: String) {
        label.text = text
        label.textColor = canChangeTurnDetectionMode ? AppColors.textPrimary : AppColors.textWeak
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
    }

    private func configureSegmentedControl(_ segmentedControl: UISegmentedControl) {
        for (index, mode) in TurnDetectionMode.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: mode.displayName, at: index, animated: false)
        }
        segmentedControl.isEnabled = canChangeTurnDetectionMode
        segmentedControl.apportionsSegmentWidthsByContent = true
        segmentedControl.selectedSegmentTintColor = AppColors.accentBlue
        segmentedControl.backgroundColor = AppColors.bgTertiary
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: AppColors.textSecondary, .font: UIFont.systemFont(ofSize: 12, weight: .medium)],
            for: .normal
        )
        segmentedControl.setTitleTextAttributes(
            [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 12, weight: .semibold)],
            for: .selected
        )
        segmentedControl.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.left.equalToSuperview().inset(20)
        }

        versionLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.left.equalTo(titleLabel.snp.right).offset(8)
            make.right.equalToSuperview().inset(20)
        }

        dividerTop.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        if agentId.isEmpty {
            sosLabel.snp.makeConstraints { make in
                make.top.equalTo(dividerTop.snp.bottom)
                make.left.equalToSuperview().inset(20)
                make.width.equalTo(32)
                make.height.equalTo(56)
            }
        } else {
            agentIdLabel.snp.makeConstraints { make in
                make.top.equalTo(dividerTop.snp.bottom)
                make.left.equalToSuperview().inset(20)
                make.width.equalTo(68)
                make.height.equalTo(56)
            }

            agentIdCopyButton.snp.makeConstraints { make in
                make.centerY.equalTo(agentIdLabel)
                make.right.equalToSuperview().inset(20)
                make.height.equalTo(32)
                make.width.greaterThanOrEqualTo(56)
            }

            agentIdValueLabel.snp.makeConstraints { make in
                make.centerY.equalTo(agentIdLabel)
                make.left.equalTo(agentIdLabel.snp.right).offset(12)
                make.right.equalTo(agentIdCopyButton.snp.left).offset(-8)
            }

            dividerAgentId.snp.makeConstraints { make in
                make.top.equalTo(agentIdLabel.snp.bottom)
                make.left.right.equalToSuperview().inset(20)
                make.height.equalTo(1)
            }

            sosLabel.snp.makeConstraints { make in
                make.top.equalTo(dividerAgentId.snp.bottom)
                make.left.equalToSuperview().inset(20)
                make.width.equalTo(32)
                make.height.equalTo(56)
            }
        }

        sosSegmentedControl.snp.makeConstraints { make in
            make.centerY.equalTo(sosLabel)
            make.left.greaterThanOrEqualTo(sosLabel.snp.right).offset(12)
            make.right.equalToSuperview().inset(20)
            make.width.equalTo(220)
            make.height.equalTo(36)
        }

        dividerMiddle.snp.makeConstraints { make in
            make.top.equalTo(sosLabel.snp.bottom)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        eosLabel.snp.makeConstraints { make in
            make.top.equalTo(dividerMiddle.snp.bottom)
            make.left.equalToSuperview().inset(20)
            make.width.equalTo(32)
            make.height.equalTo(56)
        }

        eosSegmentedControl.snp.makeConstraints { make in
            make.centerY.equalTo(eosLabel)
            make.left.greaterThanOrEqualTo(eosLabel.snp.right).offset(12)
            make.right.equalToSuperview().inset(20)
            make.width.equalTo(220)
            make.height.equalTo(36)
        }

        dividerBottom.snp.makeConstraints { make in
            make.top.equalTo(eosLabel.snp.bottom)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }
    }

    private func applyInitialSelection() {
        sosSegmentedControl.selectedSegmentIndex = TurnDetectionMode.allCases.firstIndex(of: sosMode) ?? 0
        eosSegmentedControl.selectedSegmentIndex = TurnDetectionMode.allCases.firstIndex(of: eosMode) ?? 0
    }

    @objc private func copyAgentIdButtonTapped() {
        if onCopyAgentId() {
            showToast("Agent ID copied", backgroundColor: AppColors.bgTertiary, textColor: AppColors.textPrimary)
        } else {
            showToast("Agent ID is not available", backgroundColor: AppColors.errorRedDark, textColor: .white)
        }
    }

    @objc private func sosSelectionChanged() {
        guard canChangeTurnDetectionMode else { return }
        let mode = TurnDetectionMode.allCases[safe: sosSegmentedControl.selectedSegmentIndex]
        if let mode {
            onSosModeChanged(mode)
        }
    }

    @objc private func eosSelectionChanged() {
        guard canChangeTurnDetectionMode else { return }
        let mode = TurnDetectionMode.allCases[safe: eosSegmentedControl.selectedSegmentIndex]
        if let mode {
            onEosModeChanged(mode)
        }
    }

    private var demoVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func showToast(_ message: String, backgroundColor: UIColor, textColor: UIColor) {
        let toast = UIView()
        toast.backgroundColor = backgroundColor.withAlphaComponent(0.95)
        toast.layer.cornerRadius = 12
        view.addSubview(toast)

        let label = UILabel()
        label.text = message
        label.textColor = textColor
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        toast.addSubview(label)

        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(28)
            make.width.lessThanOrEqualTo(260)
        }

        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(14)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toast.removeFromSuperview()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
