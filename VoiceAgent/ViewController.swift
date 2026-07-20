//
//  ViewController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit
import AgoraRtcKit
import AgoraRtmKit
import AgoraAgentClientToolkit
import AVFAudio

private enum ChatMessageComposerMode {
    case text
    case image
}

private final class ChatMessageInputPanelView: UIView, UITextFieldDelegate {
    private let titleLabel = UILabel()
    private let headerStackView = UIStackView()
    private let textModeButton = UIButton(type: .system)
    private let imageModeButton = UIButton(type: .system)
    private let inputRowView = UIStackView()
    private let inputTextField = UITextField()
    private let sendButton = UIButton(type: .system)

    private var mode: ChatMessageComposerMode = .text
    var onSend: ((ChatMessageComposerMode, String) -> Bool)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        applyMode(.text)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = AppColors.bgSecondary
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true

        headerStackView.axis = .horizontal
        headerStackView.alignment = .center
        headerStackView.distribution = .fill
        headerStackView.spacing = 8
        addSubview(headerStackView)

        titleLabel.text = "Chat"
        titleLabel.textColor = AppColors.textTitle
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        headerStackView.addArrangedSubview(titleLabel)

        configureModeButton(textModeButton, title: "Text", imageName: "message")
        configureModeButton(imageModeButton, title: "Image URL", imageName: "photo")
        headerStackView.addArrangedSubview(textModeButton)
        headerStackView.addArrangedSubview(imageModeButton)

        inputRowView.axis = .horizontal
        inputRowView.alignment = .fill
        inputRowView.distribution = .fill
        inputRowView.spacing = 10
        addSubview(inputRowView)

        configureInputField(inputTextField)
        inputTextField.delegate = self
        inputRowView.addArrangedSubview(inputTextField)

        configureSendButton(sendButton)
        inputRowView.addArrangedSubview(sendButton)

        textModeButton.addTarget(self, action: #selector(textModeButtonTapped), for: .touchUpInside)
        imageModeButton.addTarget(self, action: #selector(imageModeButtonTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
    }

    private func configureModeButton(_ button: UIButton, title: String, imageName: String) {
        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: imageName)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.tintColor = AppColors.textSubtitle
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.borderDefault.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: 4)
        button.clipsToBounds = true
    }

    private func configureInputField(_ textField: UITextField) {
        textField.backgroundColor = AppColors.bgTertiary
        textField.textColor = AppColors.textPrimary
        textField.tintColor = AppColors.accentBlue
        textField.font = .systemFont(ofSize: 14)
        textField.returnKeyType = .send
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = AppColors.borderDefault.cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.rightViewMode = .always
    }

    private func configureSendButton(_ button: UIButton) {
        button.setTitle("Send", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        button.backgroundColor = AppColors.btnManualBg
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
    }

    private func setupConstraints() {
        headerStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.right.equalToSuperview().inset(12)
            make.height.equalTo(36)
        }

        textModeButton.snp.makeConstraints { make in
            make.width.equalTo(82)
            make.height.equalTo(36)
        }

        imageModeButton.snp.makeConstraints { make in
            make.width.equalTo(120)
            make.height.equalTo(36)
        }

        inputRowView.snp.makeConstraints { make in
            make.top.equalTo(headerStackView.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(12)
            make.height.equalTo(48)
            make.bottom.equalToSuperview().inset(16)
        }

        sendButton.snp.makeConstraints { make in
            make.width.equalTo(72)
        }
    }

    private func applyMode(_ newMode: ChatMessageComposerMode) {
        mode = newMode
        inputTextField.attributedPlaceholder = NSAttributedString(
            string: mode == .text ? "Type a message" : "Paste image URL",
            attributes: [.foregroundColor: AppColors.textTertiary]
        )
        inputTextField.keyboardType = mode == .text ? .default : .URL
        inputTextField.autocapitalizationType = mode == .text ? .sentences : .none
        inputTextField.autocorrectionType = mode == .text ? .default : .no
        updateModeButton(textModeButton, selected: mode == .text)
        updateModeButton(imageModeButton, selected: mode == .image)
        inputTextField.reloadInputViews()
    }

    private func updateModeButton(_ button: UIButton, selected: Bool) {
        button.backgroundColor = selected ? AppColors.accentBlue : AppColors.bgTertiary
        button.setTitleColor(selected ? .white : AppColors.textSubtitle, for: .normal)
        button.tintColor = selected ? .white : AppColors.textSubtitle
    }

    @objc private func textModeButtonTapped() {
        applyMode(.text)
    }

    @objc private func imageModeButtonTapped() {
        applyMode(.image)
    }

    @objc private func sendButtonTapped() {
        sendMessage()
    }

    @discardableResult
    private func sendMessage() -> Bool {
        let sent = onSend?(mode, inputTextField.text ?? "") ?? false
        if sent {
            hide()
        }
        return sent
    }

    var isPanelVisible: Bool {
        !isHidden
    }

    func show() {
        applyMode(.text)
        inputTextField.text = ""
        isHidden = false
        inputTextField.becomeFirstResponder()
    }

    func hide() {
        guard !isHidden else { return }
        inputTextField.resignFirstResponder()
        isHidden = true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        isHidden = true
    }
}

class ViewController: UIViewController {
    private static let requestedUid = Int.random(in: 1000...9_999_999)

    // MARK: - UI Components
    private let backgroundGradientLayer = CAGradientLayer()
    private let settingsButton = UIButton(type: .system)
    private let subtitleLabel = UILabel()
    private let turnDetectionModeLabel = UILabel()
    private let logCardView = UIView()
    private let connectionStartView = ConnectionStartView()
    private let chatSessionView = ChatSessionView()
    private let chatInputPanelView = ChatMessageInputPanelView()
    private let debugInfoTextView = UITextView()
    
    // MARK: - State
    private var uid = 0
    private var channel: String = ""
    private var transcriptItems: [TranscriptItem] = []
    private var pendingTurnLatencyMetrics: [Int: TurnLatencyMetrics] = [:]
    private var isLatencyMetricsVisible: Bool = true
    private var isMicMuted: Bool = false
    private var currentAgentState: AgentState = .unknown
    private var isAgentListening = false
    private var isAgentThinking = false
    private var isAgentSpeaking = false
    private var startupState = SessionStartupState()
    private var sosDetectionMode: TurnDetectionMode = .vad
    private var eosDetectionMode: TurnDetectionMode = .semantic
    private var rtcJoinContinuation: CheckedContinuation<Void, Error>?
    private var joiningChannel: String?
    private var debugLogList: [String] = []
    
    // MARK: - Agora Components
    private var token: String = ""
    private var agentId: String = ""
    private var agentUid = 0
    private var agentManager: AgentManager?
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    
    // MARK: - Toast
    private var loadingToast: UIView?
    
    // MARK: - Debug Info Helper
    private func addDebugMessage(_ message: String) {
        print("[VoiceAgent] \(message)")

        guard !message.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.debugLogList.append(message)
            if self.debugLogList.count > 20 {
                self.debugLogList.removeFirst(self.debugLogList.count - 20)
            }
            self.renderDebugLog()
        }
    }

    private func renderDebugLog() {
        guard !debugLogList.isEmpty else {
            debugInfoTextView.attributedText = NSAttributedString(
                string: "log",
                attributes: logAttributes(color: AppColors.textSecondary)
            )
            return
        }

        let text = NSMutableAttributedString()
        for (index, log) in debugLogList.enumerated() {
            text.append(NSAttributedString(string: log, attributes: logAttributes(color: logColor(for: log))))
            if index < debugLogList.count - 1 {
                text.append(NSAttributedString(string: "\n", attributes: logAttributes(color: AppColors.textSecondary)))
            }
        }
        debugInfoTextView.attributedText = text

        let bottom = NSRange(location: max(debugInfoTextView.text.count - 1, 0), length: 1)
        debugInfoTextView.scrollRangeToVisible(bottom)
    }

    private func logAttributes(color: UIColor) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: color,
            .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        ]
    }

    private func logColor(for message: String) -> UIColor {
        let lowercased = message.lowercased()
        if lowercased.contains("failed") || lowercased.contains("error") {
            return AppColors.errorRedLight
        }
        if lowercased.contains("successfully") || lowercased.contains("success") {
            return AppColors.successGreenLight
        }
        if lowercased.contains("connecting") || lowercased.contains("starting") {
            return AppColors.warningAmberLight
        }
        return AppColors.textSecondary
    }

    private func moduleTypeValue(_ type: ModuleType) -> String {
        switch type {
        case .llm: return "llm"
        case .mllm: return "mllm"
        case .tts: return "tts"
        case .context: return "context"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    private func chatMessageTypeValue(_ type: ChatMessageType) -> String {
        switch type {
        case .text: return "text"
        case .image: return "picture"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    private var isManualSosEnabled: Bool {
        sosDetectionMode == .manual
    }

    private var isManualEosEnabled: Bool {
        eosDetectionMode == .manual
    }

    private var canChangeTurnDetectionMode: Bool {
        startupState.canStartConnection
    }

    private func refreshTurnDetectionUI() {
        turnDetectionModeLabel.text = "SOS: \(sosDetectionMode.displayName)  |  EOS: \(eosDetectionMode.displayName)"
        settingsButton.tintColor = canChangeTurnDetectionMode ? AppColors.micNormalIcon : AppColors.textWeak
        chatSessionView.updateManualActions(
            isManualSosEnabled: isManualSosEnabled,
            isManualEosEnabled: isManualEosEnabled,
            isConnected: startupState.phase == .connected
        )
    }
    
    // MARK: - Lifecycle
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        setupConstraints()
    }

    private func validateConfiguration() -> Bool {
        let missingKeys = KeyCenter.missingRequiredKeys
        guard missingKeys.isEmpty else {
            let message = "Missing backend configuration: \(missingKeys.joined(separator: ", "))"
            addDebugMessage(message)
            connectionStartView.update(for: .ready)
            showErrorToast(message)
            return false
        }

        do {
            _ = try AgentManager(baseURLString: KeyCenter.AGENT_BACKEND_URL)
            return true
        } catch {
            addDebugMessage(error.localizedDescription)
            connectionStartView.update(for: .ready)
            showErrorToast(error.localizedDescription)
            return false
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = AppColors.bgPrimary

        backgroundGradientLayer.colors = [
            AppColors.bgPrimary.cgColor,
            AppColors.bgSecondary.cgColor,
            AppColors.bgPrimary.cgColor
        ]
        backgroundGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)

        settingsButton.setImage(UIImage(systemName: "gearshape.fill")?.withRenderingMode(.alwaysTemplate), for: .normal)
        settingsButton.tintColor = AppColors.micNormalIcon
        settingsButton.backgroundColor = .clear
        settingsButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        view.addSubview(settingsButton)
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)

        subtitleLabel.text = "Real-time Voice Conversation Demo"
        subtitleLabel.textColor = AppColors.textSubtitle
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.numberOfLines = 1
        view.addSubview(subtitleLabel)

        turnDetectionModeLabel.textColor = AppColors.textTertiary
        turnDetectionModeLabel.font = .systemFont(ofSize: 11, weight: .regular)
        turnDetectionModeLabel.numberOfLines = 1
        view.addSubview(turnDetectionModeLabel)
        refreshTurnDetectionUI()

        logCardView.backgroundColor = UIColor(hex: 0x0F172A, alpha: 0.8)
        logCardView.layer.cornerRadius = 12
        logCardView.layer.borderWidth = 1
        logCardView.layer.borderColor = AppColors.borderDefault.cgColor
        logCardView.clipsToBounds = true
        view.addSubview(logCardView)

        debugInfoTextView.isEditable = false
        debugInfoTextView.isSelectable = true
        debugInfoTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        debugInfoTextView.textColor = AppColors.textSecondary
        debugInfoTextView.backgroundColor = AppColors.bgLogContent
        debugInfoTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        debugInfoTextView.textContainer.lineFragmentPadding = 0
        debugInfoTextView.text = "log"
        debugInfoTextView.indicatorStyle = .white
        logCardView.addSubview(debugInfoTextView)

        view.addSubview(chatSessionView)
        chatSessionView.tableView.delegate = self
        chatSessionView.tableView.dataSource = self
        chatSessionView.applyTableBackgroundWorkaround()
        chatSessionView.interruptButton.addTarget(self, action: #selector(interruptButtonTapped), for: .touchUpInside)
        chatSessionView.micButton.addTarget(self, action: #selector(toggleMicrophone), for: .touchUpInside)
        chatSessionView.chatButton.addTarget(self, action: #selector(chatButtonTapped), for: .touchUpInside)
        chatSessionView.manualSosButton.addTarget(self, action: #selector(manualSosButtonTapped), for: .touchUpInside)
        chatSessionView.manualEosButton.addTarget(self, action: #selector(manualEosButtonTapped), for: .touchUpInside)
        chatSessionView.endCallButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        chatSessionView.realtimeDataToggleControl.addTarget(self, action: #selector(realtimeDataToggleTapped), for: .touchUpInside)
        chatSessionView.realtimeDataSwitch.addTarget(self, action: #selector(realtimeDataSwitchChanged), for: .valueChanged)
        chatSessionView.setRealtimeDataVisible(isLatencyMetricsVisible)
        chatSessionView.updateStatusView(state: .idle)
        chatSessionView.setControlsVisible(false)
        refreshTurnDetectionUI()

        view.addSubview(connectionStartView)
        connectionStartView.startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        connectionStartView.update(for: .ready)

        view.addSubview(chatInputPanelView)
        chatInputPanelView.onSend = { [weak self] mode, input in
            switch mode {
            case .text:
                return self?.sendTextMessage(input) ?? false
            case .image:
                return self?.sendImageUrlMessage(input) ?? false
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
    }

    private func setupConstraints() {
        settingsButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(4)
            make.right.equalToSuperview().inset(16)
            make.width.height.equalTo(32)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(4)
            make.left.equalToSuperview().inset(16)
            make.right.equalTo(settingsButton.snp.left).offset(-12)
        }

        turnDetectionModeLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom)
            make.left.equalToSuperview().inset(16)
            make.right.equalTo(settingsButton.snp.left).offset(-12)
        }

        logCardView.snp.makeConstraints { make in
            make.top.equalTo(settingsButton.snp.bottom).offset(6)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(120)
        }

        debugInfoTextView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        chatSessionView.snp.makeConstraints { make in
            make.top.equalTo(logCardView.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
        }

        connectionStartView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.height.equalTo(56)
        }

        chatInputPanelView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
    }
    
    // MARK: - Engine Initialization
    @MainActor
    private func initializeEngines(appId: String, userUid: Int) throws {
        guard rtcEngine == nil, rtmEngine == nil, convoAIAPI == nil else {
            throw NSError(
                domain: "initializeEngines",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Agora engines are already initialized"]
            )
        }

        do {
            try initializeRTM(appId: appId, userUid: userUid)
            initializeRTC(appId: appId)
            try initializeConvoAIAPI()
        } catch {
            releaseAgoraResources(unsubscribeChannel: "")
            throw error
        }
    }
    
    private func initializeRTM(appId: String, userUid: Int) throws {
        let rtmConfig = AgoraRtmClientConfig(appId: appId, userId: "\(userUid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        
        do {
            let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
            self.rtmEngine = rtmClient
            addDebugMessage("RtmClient init successfully")
        } catch {
            addDebugMessage("RtmClient init failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func initializeRTC(appId: String) {
        let rtcConfig = AgoraRtcEngineConfig()
        rtcConfig.appId = appId
        rtcConfig.channelProfile = .liveBroadcasting
        rtcConfig.audioScenario = .aiClient
        let rtcEngine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        self.rtcEngine = rtcEngine
        addDebugMessage("RtcEngine init successfully")
    }
    
    private func initializeConvoAIAPI() throws {
        guard let rtcEngine = self.rtcEngine else {
            throw NSError(
                domain: "initializeConvoAIAPI",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "RTC engine is not initialized"]
            )
        }
        
        guard let rtmEngine = self.rtmEngine else {
            throw NSError(
                domain: "initializeConvoAIAPI",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "RTM engine is not initialized"]
            )
        }
        
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: false)
        let convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
        
        self.convoAIAPI = convoAIAPI
        print("[VoiceAgent] ConvoAI API initialized")
    }
    
    // MARK: - Connection Flow
    private func startConnection(requestedChannel: String, requestedUid: Int) {
        startupState.beginConnecting()
        connectionStartView.update(for: .connecting)
        refreshTurnDetectionUI()
        showLoadingToast()
        
        Task { @MainActor in
            do {
                // 1. Fetch the user RTC/RTM configuration from the local backend.
                let agentManager = try AgentManager(baseURLString: KeyCenter.AGENT_BACKEND_URL)
                self.agentManager = agentManager
                let config = try await agentManager.getConfiguration(
                    channel: requestedChannel,
                    uid: requestedUid
                )
                guard let resolvedUid = Int(config.uid), resolvedUid > 0,
                      let resolvedAgentUid = Int(config.agentUid), resolvedAgentUid > 0,
                      !config.appId.isEmpty,
                      !config.token.isEmpty,
                      !config.channelName.isEmpty else {
                    throw AgentManagerError.invalidData(
                        message: "Backend returned invalid RTC/RTM configuration"
                    )
                }
                channel = config.channelName
                uid = resolvedUid
                agentUid = resolvedAgentUid
                token = config.token
                addDebugMessage("Backend configuration received successfully")

                // 2. Initialize RTC, RTM, and Toolkit with backend-owned config.
                try initializeEngines(appId: config.appId, userUid: resolvedUid)
                convoAIAPI?.loadAudioSettings()

                // 3. Log in to RTM.
                try await loginRTM()
                
                // 4. Join RTC and wait for the real joined callback.
                try await joinRTCChannel()

                // 5. Subscribe to ConvoAI messages and require completion.
                try await subscribeConvoAIMessage()

                guard startupState.shouldStartAgent else {
                    throw NSError(
                        domain: "startConnection",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "RTC, RTM, or message subscription is not ready"
                        ]
                    )
                }

                // 6. Start the agent through the local Python backend.
                try await startAgent()
                
                startupState.markConnected()
                hideLoadingToast()
                switchToChatView()
            } catch {
                addDebugMessage("Connection failed: \(error.localizedDescription)")
                cleanupAfterConnectionFailure()
                startupState.reset()
                refreshTurnDetectionUI()
                hideLoadingToast()
                connectionStartView.update(for: .ready)
                showErrorToast(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func cleanupAfterConnectionFailure() {
        releaseAgoraResources(unsubscribeChannel: channel)
        agentId = ""
        token = ""
        agentUid = 0
        uid = 0
        channel = ""
        agentManager = nil
    }

    @MainActor
    private func ensureMicrophonePermission() async -> Bool {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return true
        case .denied:
            showErrorToast("Microphone permission is required for voice conversation.")
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if !granted {
                            self.showErrorToast("Microphone permission is required for voice conversation.")
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default:
            showErrorToast("Unable to determine microphone permission.")
            return false
        }
    }
    // MARK: - Channel Connection
    @MainActor
    private func loginRTM() async throws {
        guard let rtmEngine = self.rtmEngine else {
            throw NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM engine is not initialized"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let loginToken = self.token
            rtmEngine.login(loginToken) { res, error in
                if let error = error {
                    self.addDebugMessage("Rtm login failed, code: \(error.code)")
                    continuation.resume(
                        throwing: NSError(
                            domain: "loginRTM",
                            code: error.code,
                            userInfo: [
                                NSLocalizedDescriptionKey: "RTM login failed: \(error.localizedDescription)"
                            ]
                        )
                    )
                } else if let _ = res {
                    self.addDebugMessage("Rtm login successful")
                    self.startupState.markRTMLoggedIn()
                    continuation.resume()
                } else {
                    self.addDebugMessage("Rtm login failed, code: -1")
                    continuation.resume(
                        throwing: NSError(
                            domain: "loginRTM",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "RTM login failed"]
                        )
                    )
                }
            }
        }
    }
    
    @MainActor
    private func joinRTCChannel() async throws {
        guard let rtcEngine = self.rtcEngine else {
            throw NSError(domain: "joinRTCChannel", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTC engine is not initialized"])
        }
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = false
        joiningChannel = channel
        let result = rtcEngine.joinChannel(byToken: token, channelId: channel, uid: UInt(uid), mediaOptions: options)
        if result != 0 {
            joiningChannel = nil
            addDebugMessage("Rtc joinChannel failed ret: \(result)")
            throw NSError(domain: "joinRTCChannel", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Failed to join RTC channel. Error code: \(result)"])
        } else {
            if startupState.rtcJoined {
                print("[VoiceAgent] RTC join callback already received")
                return
            }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.rtcJoinContinuation = continuation
            }
        }
    }
    
    @MainActor
    private func subscribeConvoAIMessage() async throws {
        guard let convoAIAPI = self.convoAIAPI else {
            throw NSError(domain: "subscribeConvoAIMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: "ConvoAI API is not initialized"])
        }
            
        return try await withCheckedThrowingContinuation { continuation in
            convoAIAPI.subscribeMessage(channelName: channel) { err in
                if let error = err {
                    print("[VoiceAgent] ConvoAI subscription failed: \(error.message)")
                    continuation.resume(throwing: NSError(domain: "subscribeConvoAIMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: "ConvoAI subscription failed: \(error.message)"]))
                } else {
                    print("[VoiceAgent] ConvoAI subscribed")
                    self.startupState.markMessageSubscribed()
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Agent Management
    private func startAgent() async throws {
        guard let agentManager else {
            throw AgentManagerError.invalidData(message: "Backend client is not initialized")
        }
        let result = try await agentManager.startAgent(
            StartAgentRequest(
                channelName: channel,
                agentUid: agentUid,
                userUid: uid,
                startOfSpeechMode: sosDetectionMode.rawValue,
                endOfSpeechMode: eosDetectionMode.rawValue
            )
        )
        agentId = result.agentId
        addDebugMessage("Agent start successfully")
        print("[VoiceAgent] Agent started successfully, agentId: \(result.agentId)")
    }
    
    // MARK: - View Management
    private func switchToChatView() {
        connectionStartView.isHidden = true
        chatSessionView.setControlsVisible(true)
        refreshTurnDetectionUI()
    }
    
    private func switchToConfigView() {
        connectionStartView.isHidden = false
        chatInputPanelView.hide()
        chatSessionView.setControlsVisible(false)
        refreshTurnDetectionUI()
    }

    @MainActor
    private func releaseAgoraResources(unsubscribeChannel: String) {
        let convoAIAPIToRelease = convoAIAPI
        let rtcEngineToRelease = rtcEngine
        let rtmEngineToRelease = rtmEngine
        convoAIAPI = nil
        rtcEngine = nil
        rtmEngine = nil

        rtcJoinContinuation?.resume(
            throwing: NSError(
                domain: "joinRTCChannel",
                code: -999,
                userInfo: [NSLocalizedDescriptionKey: "RTC join cancelled"]
            )
        )
        rtcJoinContinuation = nil
        joiningChannel = nil

        if !unsubscribeChannel.isEmpty {
            convoAIAPIToRelease?.unsubscribeMessage(channelName: unsubscribeChannel) { error in
                if let error {
                    print("[VoiceAgent] ConvoAI unsubscribe failed: \(error.message)")
                }
            }
        }
        rtcEngineToRelease?.leaveChannel()
        convoAIAPIToRelease?.removeHandler(handler: self)
        convoAIAPIToRelease?.destroy()

        if let rtmEngineToRelease {
            rtmEngineToRelease.logout(nil)
            let destroyResult = rtmEngineToRelease.destroy()
            if destroyResult.rawValue != 0 {
                print("[VoiceAgent] RTM destroy failed, code: \(destroyResult.rawValue)")
            }
        }

        if rtcEngineToRelease != nil {
            AgoraRtcEngineKit.destroy()
        }
    }

    private func resetConnectionState() {
        releaseAgoraResources(unsubscribeChannel: channel)
        
        switchToConfigView()
        startupState.reset()
        connectionStartView.update(for: .ready)
        refreshTurnDetectionUI()
        
        transcriptItems.removeAll()
        pendingTurnLatencyMetrics.removeAll()
        chatSessionView.tableView.reloadData()
        isMicMuted = false
        isAgentListening = false
        isAgentThinking = false
        isAgentSpeaking = false
        currentAgentState = .idle
        chatSessionView.updateStatusView(state: .idle)
        agentId = ""
        token = ""
        agentUid = 0
        uid = 0
        channel = ""
        agentManager = nil
    }
    
    // MARK: - UI Updates
    private func updateAgentStatusView() {
        chatSessionView.updateStatusView(state: currentAgentState)
    }

    private func updateAgentActivityState() {
        if isAgentSpeaking {
            currentAgentState = .speaking
        } else if isAgentThinking {
            currentAgentState = .thinking
        } else if isAgentListening {
            currentAgentState = .listening
        } else {
            currentAgentState = .silent
        }
        updateAgentStatusView()
    }
    
    // MARK: - Actions
    @objc private func settingsButtonTapped() {
        let settingsViewController = TurnDetectionSettingsViewController(
            sosMode: sosDetectionMode,
            eosMode: eosDetectionMode,
            agentId: agentId,
            canChangeTurnDetectionMode: canChangeTurnDetectionMode,
            onSosModeChanged: { [weak self] mode in
                self?.setSosDetectionMode(mode)
            },
            onEosModeChanged: { [weak self] mode in
                self?.setEosDetectionMode(mode)
            },
            onCopyAgentId: { [weak self] in
                self?.copyAgentId() ?? false
            }
        )
        present(settingsViewController, animated: true)
    }

    private func setSosDetectionMode(_ mode: TurnDetectionMode) {
        guard canChangeTurnDetectionMode else {
            addDebugMessage("Turn detection mode cannot be changed after startup")
            return
        }
        sosDetectionMode = mode
        refreshTurnDetectionUI()
    }

    private func setEosDetectionMode(_ mode: TurnDetectionMode) {
        guard canChangeTurnDetectionMode else {
            addDebugMessage("Turn detection mode cannot be changed after startup")
            return
        }
        eosDetectionMode = mode
        refreshTurnDetectionUI()
    }

    @objc private func startButtonTapped() {
        guard validateConfiguration() else { return }

        guard startupState.beginPermissionRequest() else {
            addDebugMessage("Start ignored: session is already connecting")
            return
        }
        refreshTurnDetectionUI()

        Task { @MainActor in
            let granted = await ensureMicrophonePermission()
            guard granted else {
                startupState.reset()
                connectionStartView.update(for: .ready)
                refreshTurnDetectionUI()
                return
            }

            let requestedChannel = "channel_swift_\(Int.random(in: 100000...999999))"
            startConnection(requestedChannel: requestedChannel, requestedUid: Self.requestedUid)
        }
    }
    
    @objc private func toggleMicrophone() {
        isMicMuted.toggle()
        chatSessionView.updateMicButtonState(isMuted: isMicMuted)
        rtcEngine?.adjustRecordingSignalVolume(isMicMuted ? 0 : 100)
    }

    @objc private func chatButtonTapped() {
        guard startupState.phase == .connected else {
            addDebugMessage("Open chat failed error=Agent is not connected")
            return
        }
        if chatInputPanelView.isPanelVisible {
            chatInputPanelView.hide()
        } else {
            chatInputPanelView.show()
        }
    }

    @objc private func interruptButtonTapped() {
        sendInterrupt()
    }

    @objc private func manualSosButtonTapped() {
        guard isManualSosEnabled else {
            addDebugMessage("Manual SOS publish failed error=Manual SOS is disabled for this session")
            return
        }
        publishManualTurn(action: .sos)
    }

    @objc private func manualEosButtonTapped() {
        guard isManualEosEnabled else {
            addDebugMessage("Manual EOS publish failed error=Manual EOS is disabled for this session")
            return
        }
        publishManualTurn(action: .eos)
    }

    @objc private func realtimeDataToggleTapped() {
        isLatencyMetricsVisible.toggle()
        chatSessionView.setRealtimeDataVisible(isLatencyMetricsVisible)
        chatSessionView.tableView.reloadData()
    }

    @objc private func realtimeDataSwitchChanged(_ sender: UISwitch) {
        isLatencyMetricsVisible = sender.isOn
        chatSessionView.setRealtimeDataVisible(isLatencyMetricsVisible)
        chatSessionView.tableView.reloadData()
    }

    private func copyAgentId() -> Bool {
        let currentAgentId = agentId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentAgentId.isEmpty else {
            addDebugMessage("Copy agent ID failed error=Agent ID is not available")
            return false
        }

        UIPasteboard.general.string = currentAgentId
        addDebugMessage("Agent ID copied successfully")
        return true
    }

    private func sendTextMessage(_ text: String) -> Bool {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            addDebugMessage("Send text failed error=Text is empty")
            return false
        }
        let message = TextMessage(priority: .interrupt, interruptable: true, text: content)
        return sendChatMessage(label: "Text", message: message)
    }

    private func sendImageUrlMessage(_ imageUrl: String) -> Bool {
        let url = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            addDebugMessage("Send image failed error=Image URL is empty")
            return false
        }
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
            addDebugMessage("Send image failed error=Image URL must start with http:// or https://")
            return false
        }
        let message = ImageMessage(uuid: UUID().uuidString, url: url, base64: nil)
        return sendChatMessage(label: "Image", message: message)
    }

    private func sendInterrupt() {
        guard let convoAIAPI = requireConnectedConvoAIAPI(action: "Interrupt") else { return }
        convoAIAPI.interrupt(agentUserId: "\(agentUid)") { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.addDebugMessage("Interrupt failed error=\(error.message)")
                } else {
                    self?.addDebugMessage("Interrupt sent successfully")
                }
            }
        }
    }

    private func sendChatMessage(label: String, message: ChatMessage) -> Bool {
        guard let convoAIAPI = requireConnectedConvoAIAPI(action: "Send \(label)") else {
            return false
        }
        convoAIAPI.chat(agentUserId: "\(agentUid)", message: message) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.addDebugMessage("Send \(label) failed error=\(error.message)")
                } else {
                    self?.addDebugMessage("Send \(label) successfully")
                }
            }
        }
        return true
    }

    private func requireConnectedConvoAIAPI(action: String) -> ConversationalAIAPI? {
        guard startupState.phase == .connected else {
            addDebugMessage("\(action) failed error=Agent is not connected")
            return nil
        }
        guard let convoAIAPI = convoAIAPI else {
            addDebugMessage("\(action) failed error=ConversationalAIAPI is not ready")
            return nil
        }
        return convoAIAPI
    }

    private func publishManualTurn(action: ManualTurnDemoUI.Action) {
        guard let convoAIAPI = convoAIAPI else {
            addDebugMessage("Manual \(action.label) publish failed error=ConversationalAIAPI is not ready")
            return
        }

        let completion: (String, ConversationalAIAPIError?) -> Void = { [weak self] requestId, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.addDebugMessage(ManualTurnDemoUI.formatPublishFailureLog(action: action, requestId: requestId, errorMessage: error.message))
                } else {
                    self?.addDebugMessage(ManualTurnDemoUI.formatPublishLog(action: action, requestId: requestId))
                }
            }
        }

        switch action {
        case .sos:
            guard let manualSOS = convoAIAPI.manualSOS else {
                addDebugMessage("Manual SOS publish failed error=manualSOS is not supported")
                return
            }
            manualSOS("\(agentUid)", completion)
        case .eos:
            guard let manualEOS = convoAIAPI.manualEOS else {
                addDebugMessage("Manual EOS publish failed error=manualEOS is not supported")
                return
            }
            manualEOS("\(agentUid)", completion)
        }
    }
    
    @objc private func endCall() {
        let activeAgentId = agentId
        let activeAgentManager = agentManager
        if !activeAgentId.isEmpty, let activeAgentManager {
            Task { [weak self] in
                do {
                    try await activeAgentManager.stopAgent(agentId: activeAgentId)
                    self?.addDebugMessage("Agent stopped successfully")
                } catch {
                    self?.addDebugMessage("Agent stop failed: \(error.localizedDescription)")
                }
            }
        }
        resetConnectionState()
    }
    
    // MARK: - Toast
    private func showLoadingToast() {
        let toast = UIView()
        toast.backgroundColor = AppColors.bgSecondary.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        toast.layer.borderWidth = 0.5
        toast.layer.borderColor = AppColors.borderDefault.cgColor
        view.addSubview(toast)
        
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = AppColors.accentBlue
        indicator.startAnimating()
        toast.addSubview(indicator)
        
        toast.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(100)
        }
        
        indicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        loadingToast = toast
    }
    
    private func hideLoadingToast() {
        loadingToast?.removeFromSuperview()
        loadingToast = nil
    }
    
    private func showErrorToast(_ message: String) {
        showToast(message, backgroundColor: AppColors.errorRedDark.withAlphaComponent(0.9), textColor: .white)
    }

    private func showToast(_ message: String, backgroundColor: UIColor, textColor: UIColor) {
        let toast = UIView()
        toast.backgroundColor = backgroundColor
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
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }
        
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toast.removeFromSuperview()
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transcriptItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TranscriptMessageCell.reuseIdentifier, for: indexPath) as! TranscriptMessageCell
        let item = transcriptItems[indexPath.row]
        cell.configure(
            with: item.transcript,
            latencyMetrics: item.latencyMetrics,
            isLatencyMetricsVisible: isLatencyMetricsVisible
        )
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - AgoraRtcEngineDelegate
extension ViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        guard joiningChannel == channel else {
            print("[VoiceAgent] Ignore stale RTC join callback, channel: \(channel), joiningChannel: \(joiningChannel ?? "")")
            return
        }
        addDebugMessage("Rtc onJoinChannelSuccess, channel:\(channel) uid:\(uid)")
        joiningChannel = nil
        startupState.markRTCJoined()
        rtcJoinContinuation?.resume()
        rtcJoinContinuation = nil
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        addDebugMessage("Rtc onUserJoined, uid:\(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        addDebugMessage("Rtc onUserOffline, uid:\(uid)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        addDebugMessage("Rtc onLeaveChannel")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        addDebugMessage("Rtc onError: \(errorCode.rawValue)")
        if let rtcJoinContinuation {
            rtcJoinContinuation.resume(throwing: NSError(domain: "joinRTCChannel", code: Int(errorCode.rawValue), userInfo: [NSLocalizedDescriptionKey: "RTC error: \(errorCode.rawValue)"]))
            self.rtcJoinContinuation = nil
        }
    }
}

// MARK: - AgoraRtmClientDelegate
extension ViewController: AgoraRtmClientDelegate {
    func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        switch event.currentState {
        case .connected:
            addDebugMessage("Rtm connected successfully")
        case .failed:
            addDebugMessage("Rtm connected failed")
        default:
            break
        }
    }
}

// MARK: - ConversationalAIAPIEventHandler
extension ViewController: ConversationalAIAPIEventHandler {
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
    }
    
    func onMessageError(agentUserId: String, error: MessageError) {
        addDebugMessage("Message error: type=\(chatMessageTypeValue(error.type)), code=\(error.code), msg=\(error.message)")
    }
    
    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        addDebugMessage(
            "Message receipt: type=\(chatMessageTypeValue(messageReceipt.messageType)), module=\(moduleTypeValue(messageReceipt.moduleType)), turn=\(messageReceipt.turnId)"
        )
    }

    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
    }

    func onAgentListeningChanged(agentUserId: String, isListening: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAgentListening = isListening
            self.updateAgentActivityState()
        }
    }

    func onAgentThinkingChanged(agentUserId: String, isThinking: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAgentThinking = isThinking
            self.updateAgentActivityState()
        }
    }

    func onAgentSpeakingChanged(agentUserId: String, isSpeaking: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAgentSpeaking = isSpeaking
            self.updateAgentActivityState()
        }
    }
    
    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
    }
    
    func onAgentMetrics(agentUserId: String, metrics: Metric) {
    }

    func onTurnFinished(agentUserId: String, turn: Turn) {
        DispatchQueue.main.async { [weak self] in
            self?.updateTurnLatencyMetrics(turn)
        }
    }
    
    func onAgentError(agentUserId: String, error: ModuleError) {
        addDebugMessage("Agent error: type=\(moduleTypeValue(error.type)), code=\(error.code), msg=\(error.message)")
    }

    func onUserManualSosEvent(agentUserId: String, event: UserManualSosEvent) {
        addDebugMessage(ManualTurnDemoUI.formatUserResultLog(action: .sos, payload: event.payload))
    }

    func onUserManualEosEvent(agentUserId: String, event: UserManualEosEvent) {
        addDebugMessage(ManualTurnDemoUI.formatUserResultLog(action: .eos, payload: event.payload))
    }

    func onAgentManualEosEvent(agentUserId: String, event: AgentManualEosEvent) {
        addDebugMessage(ManualTurnDemoUI.formatAgentEosLog(payload: event.payload))
    }
    
    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let latencyMetrics = transcript.type == .agent
                ? self.pendingTurnLatencyMetrics.removeValue(forKey: transcript.turnId)
                : nil
            
            if let index = self.transcriptItems.firstIndex(where: {
                $0.transcript.turnId == transcript.turnId &&
                $0.transcript.type.rawValue == transcript.type.rawValue &&
                $0.transcript.userId == transcript.userId
            }) {
                let existingLatencyMetrics = self.transcriptItems[index].latencyMetrics
                self.transcriptItems[index] = TranscriptItem(
                    transcript: transcript,
                    latencyMetrics: latencyMetrics ?? existingLatencyMetrics
                )
            } else {
                self.transcriptItems.append(TranscriptItem(transcript: transcript, latencyMetrics: latencyMetrics))
            }
            
            self.chatSessionView.tableView.reloadData()
            
            if !self.transcriptItems.isEmpty {
                let indexPath = IndexPath(row: self.transcriptItems.count - 1, section: 0)
                self.chatSessionView.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }

    private func updateTurnLatencyMetrics(_ turn: Turn) {
        let metrics = turn.toLatencyMetrics()
        if let index = transcriptItems.firstIndex(where: {
            $0.transcript.turnId == turn.turnId &&
                $0.transcript.type == .agent
        }) {
            transcriptItems[index].latencyMetrics = metrics
            chatSessionView.tableView.reloadData()
        } else {
            pendingTurnLatencyMetrics[turn.turnId] = metrics
        }
    }
    
    func onDebugLog(log: String) {
    }
}

private extension Turn {
    func toLatencyMetrics() -> TurnLatencyMetrics {
        TurnLatencyMetrics(
            turnId: turnId,
            e2eLatencyMs: e2eLatency.nonZeroRoundedInt,
            transportLatencyMs: segmentedLatency.transport.nonZeroRoundedInt,
            algorithmProcessingLatencyMs: segmentedLatency.algorithmProcessing.nonZeroRoundedInt,
            asrLatencyMs: segmentedLatency.asrTTLW.nonZeroRoundedInt,
            llmLatencyMs: segmentedLatency.llmTTFT.nonZeroRoundedInt,
            ttsLatencyMs: segmentedLatency.ttsTTFB.nonZeroRoundedInt
        )
    }
}

private extension Double {
    var roundedInt: Int {
        Int(self.rounded())
    }

    var nonZeroRoundedInt: Int? {
        self > 0 ? roundedInt : nil
    }
}
