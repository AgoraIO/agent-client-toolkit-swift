import UIKit
import SnapKit

final class TurnDetectionSettingsViewController: UIViewController {
    private let titleLabel = UILabel()
    private let dividerTop = UIView()
    private let dividerMiddle = UIView()
    private let dividerBottom = UIView()
    private let sosLabel = UILabel()
    private let eosLabel = UILabel()
    private let sosSegmentedControl = UISegmentedControl()
    private let eosSegmentedControl = UISegmentedControl()

    private let sosMode: TurnDetectionMode
    private let eosMode: TurnDetectionMode
    private let canChangeTurnDetectionMode: Bool
    private let onSosModeChanged: (TurnDetectionMode) -> Void
    private let onEosModeChanged: (TurnDetectionMode) -> Void

    init(
        sosMode: TurnDetectionMode,
        eosMode: TurnDetectionMode,
        canChangeTurnDetectionMode: Bool,
        onSosModeChanged: @escaping (TurnDetectionMode) -> Void,
        onEosModeChanged: @escaping (TurnDetectionMode) -> Void
    ) {
        self.sosMode = sosMode
        self.eosMode = eosMode
        self.canChangeTurnDetectionMode = canChangeTurnDetectionMode
        self.onSosModeChanged = onSosModeChanged
        self.onEosModeChanged = onEosModeChanged
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

        [dividerTop, dividerMiddle, dividerBottom].forEach { divider in
            divider.backgroundColor = AppColors.borderDefault
            view.addSubview(divider)
        }

        configureRowLabel(sosLabel, text: "SOS")
        configureRowLabel(eosLabel, text: "EOS")
        view.addSubview(sosLabel)
        view.addSubview(eosLabel)

        configureSegmentedControl(sosSegmentedControl)
        configureSegmentedControl(eosSegmentedControl)
        view.addSubview(sosSegmentedControl)
        view.addSubview(eosSegmentedControl)

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
            make.left.right.equalToSuperview().inset(20)
        }

        dividerTop.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(1)
        }

        sosLabel.snp.makeConstraints { make in
            make.top.equalTo(dividerTop.snp.bottom)
            make.left.equalToSuperview().inset(20)
            make.width.equalTo(32)
            make.height.equalTo(56)
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
