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
    private static let defaultLLMGreetingMessage = "hello man, I am an AI robot, I can do anything for you"
    private static let defaultLLMFailureMessage = "Sorry, I don't know how to answer your question"

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
    private let uid = Int.random(in: 1000...9999999)
    private var channel: String = ""
    private var transcriptItems: [TranscriptItem] = []
    private var pendingTurnLatencyMetrics: [Int: TurnLatencyMetrics] = [:]
    private var isLatencyMetricsVisible: Bool = true
    private var isMicMuted: Bool = false
    private var currentAgentState: AgentState = .unknown
    private var startupState = SessionStartupState()
    private var sosDetectionMode: TurnDetectionMode = .vad
    private var eosDetectionMode: TurnDetectionMode = .semantic
    private var rtcJoinContinuation: CheckedContinuation<Void, Error>?
    private var joiningChannel: String?
    private var debugLogList: [String] = []
    
    // MARK: - Agora Components
    private var token: String = ""
    private var agentToken: String = ""
    private var authToken: String = ""
    private var agentId: String = ""
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    private let agentUid = Int.random(in: 10000000...99999999)
    
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
        initializeEnginesIfNeeded()
    }

    private func validateConfiguration() -> Bool {
        let missingKeys = KeyCenter.missingRequiredKeys
        guard missingKeys.isEmpty else {
            let message = "Missing Agora configuration: \(missingKeys.joined(separator: ", "))"
            addDebugMessage(message)
            connectionStartView.update(for: .ready)
            showErrorToast(message)
            return false
        }

        return true
    }

    private func initializeEnginesIfNeeded() {
        guard rtcEngine == nil || rtmEngine == nil || convoAIAPI == nil else { return }
        guard validateConfiguration() else { return }
        initializeEngines()
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
    private func initializeEngines() {
        initializeRTM()
        initializeRTC()
        initializeConvoAIAPI()
    }
    
    private func initializeRTM() {
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.APP_ID, userId: "\(uid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        
        do {
            let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
            self.rtmEngine = rtmClient
            addDebugMessage("RtmClient init successfully")
        } catch {
            addDebugMessage("RtmClient init failed")
        }
    }
    
    private func initializeRTC() {
        let rtcConfig = AgoraRtcEngineConfig()
        rtcConfig.appId = KeyCenter.APP_ID
        rtcConfig.channelProfile = .liveBroadcasting
        rtcConfig.audioScenario = .aiClient
        let rtcEngine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        self.rtcEngine = rtcEngine
        addDebugMessage("RtcEngine init successfully")
    }
    
    private func initializeConvoAIAPI() {
        guard let rtcEngine = self.rtcEngine else {
            print("[VoiceAgent] ConvoAI API initialization failed: RTC engine is not initialized")
            return
        }
        
        guard let rtmEngine = self.rtmEngine else {
            print("[VoiceAgent] ConvoAI API initialization failed: RTM engine is not initialized")
            return
        }
        
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: false)
        let convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
        
        self.convoAIAPI = convoAIAPI
        print("[VoiceAgent] ConvoAI API initialized")
    }
    
    // MARK: - Connection Flow
    private func startConnection() {
        startupState.beginConnecting()
        connectionStartView.update(for: .connecting)
        refreshTurnDetectionUI()
        showLoadingToast()
        
        Task {
            do {
                // 1. Generate the user token
                try await generateUserToken()
                
                // 2. Log in to RTM
                try await loginRTM()
                
                // 3. Join the RTC channel and wait for the real joined callback
                try await joinRTCChannel()

                guard startupState.shouldStartAgent else {
                    throw NSError(domain: "startConnection", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTC or RTM is not ready"])
                }

                // 4. Subscribe to ConvoAI messages
                try await subscribeConvoAIMessage()
                
                // 5. Generate the agent token
                try await generateAgentToken()

                // 6. Generate the REST auth token
                try await generateAuthToken()

                // 7. Start the agent
                try await startAgent()
                
                await MainActor.run {
                    startupState.markConnected()
                    hideLoadingToast()
                    switchToChatView()
                }
            } catch {
                await MainActor.run {
                    cleanupAfterConnectionFailure()
                    startupState.reset()
                    refreshTurnDetectionUI()
                    hideLoadingToast()
                    connectionStartView.update(for: .ready)
                    showErrorToast(error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private func cleanupAfterConnectionFailure() {
        rtcJoinContinuation?.resume(throwing: NSError(domain: "joinRTCChannel", code: -999, userInfo: [NSLocalizedDescriptionKey: "RTC join cancelled"]))
        rtcJoinContinuation = nil
        joiningChannel = nil
        rtcEngine?.leaveChannel()
        convoAIAPI?.unsubscribeMessage(channelName: channel) { _ in }
        rtmEngine?.logout { _, _ in }
        agentId = ""
        token = ""
        agentToken = ""
        authToken = ""
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
    
    // MARK: - Token Generation
    private func generateUserToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(uid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    self.addDebugMessage("Generate user token failed")
                    continuation.resume(throwing: NSError(domain: "generateUserToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get user token. Please try again."]))
                    return
                }
                self.token = token
                self.addDebugMessage("Generate user token successfully")
                continuation.resume()
            }
        }
    }
    
    private func generateAgentToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(agentUid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    self.addDebugMessage("Generate agent token failed")
                    continuation.resume(throwing: NSError(domain: "generateAgentToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get agent token. Please try again."]))
                    return
                }
                self.agentToken = token
                self.addDebugMessage("Generate agent token successfully")
                continuation.resume()
            }
        }
    }

    private func generateAuthToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(agentUid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    self.addDebugMessage("Generate auth token failed")
                    continuation.resume(throwing: NSError(domain: "generateAuthToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get auth token. Please try again."]))
                    return
                }
                self.authToken = token
                self.addDebugMessage("Generate auth token successfully")
                continuation.resume()
            }
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
            let performLogin = { [self] in
                rtmEngine.login(loginToken) { res, error in
                    if let error = error {
                        self.addDebugMessage("Rtm login failed, code: \(error.code)")
                        continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM login failed: \(error.localizedDescription)"]))
                    } else if let _ = res {
                        self.addDebugMessage("Rtm login successful")
                        self.startupState.markRTMLoggedIn()
                        continuation.resume()
                    } else {
                        self.addDebugMessage("Rtm login failed, code: -1")
                        continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM login failed"]))
                    }
                }
            }

            rtmEngine.logout { _, error in
                if let reason = error?.reason, !reason.isEmpty {
                    print("[VoiceAgent] RTM pre-login logout: \(reason)")
                }
                performLogin()
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
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Agent Management
    private func startOfSpeechConfig(for mode: TurnDetectionMode) -> [String: Any] {
        switch mode {
        case .vad:
            return [
                "mode": mode.rawValue,
                "vad_config": [
                    "interrupt_duration_ms": 500,
                    "speaking_interrupt_duration_ms": 300,
                    "prefix_padding_ms": 800
                ]
            ]
        case .semantic:
            return [
                "mode": mode.rawValue,
                "semantic_config": [
                    "interrupt_duration_ms": 200,
                    "prefix_padding_ms": 920,
                    "speaking_interrupt_duration_ms": 350,
                    "ignored_words": ignoredTurnDetectionWords()
                ]
            ]
        case .manual:
            return [
                "mode": mode.rawValue
            ]
        }
    }

    private func endOfSpeechConfig(for mode: TurnDetectionMode) -> [String: Any] {
        switch mode {
        case .vad:
            return [
                "mode": mode.rawValue,
                "vad_config": [
                    "silence_duration_ms": 660
                ]
            ]
        case .semantic:
            return [
                "mode": mode.rawValue,
                "semantic_config": [
                    "silence_duration_ms": 480,
                    "max_wait_ms": 1200,
                    "pause_state_enabled": false
                ]
            ]
        case .manual:
            return [
                "mode": mode.rawValue
            ]
        }
    }

    private func ignoredTurnDetectionWords() -> [String] {
        return ["uh-huh", "okay"]
    }

    private func startAgent() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let parameter: [String: Any] = [
                "name": channel,
                "properties": [
                    "channel": channel,
                    "token": agentToken,
                    "agent_rtc_uid": "\(agentUid)",
                    "remote_rtc_uids": ["\(uid)"],
                    "enable_string_uid": false,
                    "idle_timeout": 120,
                    "advanced_features": [
                        "enable_aivad": false,
                        "enable_bhvs": true,
                        "enable_sal": false,
                        "enable_rtm": true
                    ],
                    "asr": [
                        "vendor": KeyCenter.ASR_VENDOR,
                        "params": [
                            "api_key": KeyCenter.ASR_API_KEY,
                            "model": KeyCenter.ASR_MODEL
                        ]
                    ],
                    "tts": [
                        "vendor": KeyCenter.TTS_VENDOR,
                        "params": [
                            "key": KeyCenter.TTS_KEY,
                            "model_id": KeyCenter.TTS_MODEL_ID,
                            "voice_id": KeyCenter.TTS_VOICE_ID,
                            "sample_rate": KeyCenter.TTS_SAMPLE_RATE
                        ]
                    ],
                    "llm": [
                        "url": KeyCenter.LLM_URL,
                        "api_key": KeyCenter.LLM_API_KEY,
                        "params": [
                            "model": KeyCenter.LLM_MODEL
                        ],
                        "greeting_message": Self.defaultLLMGreetingMessage,
                        "failure_message": Self.defaultLLMFailureMessage
                    ],
                    "parameters": [
                        "enable_metrics": true,
                        "enable_error_message": true,
                        "output_audio_codec": "OPUSFB",
                        "audio_scenario": "default",
                        "transcript": [
                            "enable": true,
                            "protocol_version": "v2",
                            "enable_words": false
                        ],
                        "data_channel": "rtm"
                    ],
                    "turn_detection": [
                        "mode": "default",
                        "config": [
                            "speech_threshold": 0.6,
                            "start_of_speech": startOfSpeechConfig(for: sosDetectionMode),
                            "end_of_speech": endOfSpeechConfig(for: eosDetectionMode)
                        ]
                    ]
                ] as [String: Any]
            ]
            AgentManager.startAgent(parameter: parameter, token: self.authToken) { agentId, error in
                if let error = error {
                    self.addDebugMessage("Agent start failed")
                    continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]))
                    return
                }
                
                if let agentId = agentId {
                    self.agentId = agentId
                    self.addDebugMessage("Agent start successfully")
                    print("[VoiceAgent] Agent started successfully, agentId: \(agentId)")
                    continuation.resume()
                } else {
                    self.addDebugMessage("Agent start failed")
                    continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "Agent start failed: missing agentId"]))
                }
            }
        }
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
    
    private func resetConnectionState() {
        rtcJoinContinuation?.resume(throwing: NSError(domain: "joinRTCChannel", code: -999, userInfo: [NSLocalizedDescriptionKey: "RTC join cancelled"]))
        rtcJoinContinuation = nil
        rtcEngine?.leaveChannel()
        rtmEngine?.logout { _, errorInfo in
            if let reason = errorInfo?.reason, !reason.isEmpty {
                print("[VoiceAgent] RTM logout failed: \(reason)")
            }
        }
        convoAIAPI?.unsubscribeMessage(channelName: channel, completion: { error in
            if let error = error {
                print("[VoiceAgent] ConvoAI unsubscribe failed: \(error.message)")
            }
        })
        joiningChannel = nil
        
        switchToConfigView()
        startupState.reset()
        connectionStartView.update(for: .ready)
        refreshTurnDetectionUI()
        
        transcriptItems.removeAll()
        pendingTurnLatencyMetrics.removeAll()
        chatSessionView.tableView.reloadData()
        isMicMuted = false
        currentAgentState = .idle
        chatSessionView.updateStatusView(state: .idle)
        agentId = ""
        token = ""
        agentToken = ""
        authToken = ""
    }
    
    // MARK: - UI Updates
    private func updateAgentStatusView() {
        chatSessionView.updateStatusView(state: currentAgentState)
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
        initializeEnginesIfNeeded()

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

            self.channel = "channel_swift_\(Int.random(in: 100000...999999))"
            startConnection()
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
        if !activeAgentId.isEmpty {
            AgentManager.stopAgent(agentId: activeAgentId, token: authToken) { [weak self] error in
                if error == nil {
                    self?.addDebugMessage("Agent stopped successfully")
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAgentState = event.state
            self.updateAgentStatusView()
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
