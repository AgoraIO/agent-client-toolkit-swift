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

class ViewController: UIViewController {
    // MARK: - UI Components
    private let backgroundGradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let logCardView = UIView()
    private let connectionStartView = ConnectionStartView()
    private let chatSessionView = ChatSessionView()
    private let debugInfoTextView = UITextView()
    
    // MARK: - State
    private let uid = Int.random(in: 1000...9999999)
    private var channel: String = ""
    private var transcripts: [Transcript] = []
    private var isMicMuted: Bool = false
    private var isLoading: Bool = false
    private var isError: Bool = false
    private var initializationError: Error?
    private var currentAgentState: AgentState = .unknown
    private var startupState = SessionStartupState()
    private var rtcJoinContinuation: CheckedContinuation<Void, Error>?
    private var debugLogList: [String] = []
    
    // MARK: - Agora Components
    private var token: String = ""
    private var agentToken: String = ""
    // Auth token for REST API (app-credentials mode, requires APP_CERTIFICATE)
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
            initializationError = NSError(
                domain: "KeyCenter",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
            isError = true
            connectionStartView.update(for: .error)
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

        titleLabel.text = "Agora Conversational AI"
        titleLabel.textColor = AppColors.textTitle
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.numberOfLines = 1
        view.addSubview(titleLabel)

        subtitleLabel.text = "Real-time Voice Conversation Demo"
        subtitleLabel.textColor = AppColors.textSubtitle
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.numberOfLines = 1
        view.addSubview(subtitleLabel)

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
        chatSessionView.micButton.addTarget(self, action: #selector(toggleMicrophone), for: .touchUpInside)
        chatSessionView.endCallButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        chatSessionView.updateStatusView(state: .idle)
        chatSessionView.setControlsVisible(false)

        view.addSubview(connectionStartView)
        connectionStartView.startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        connectionStartView.update(for: .ready)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
    }

    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.left.right.equalToSuperview().inset(16)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.left.right.equalToSuperview().inset(16)
        }

        logCardView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
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
    }
    
    // MARK: - Engine Initialization
    private func initializeEngines() {
        initializeRTM()
        initializeRTC()
        initializeConvoAIAPI()
    }
    
    private func initializeRTM() {
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.AG_APP_ID, userId: "\(uid)")
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
        rtcConfig.appId = KeyCenter.AG_APP_ID
        rtcConfig.channelProfile = .liveBroadcasting
        rtcConfig.audioScenario = .aiClient
        let rtcEngine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        
        rtcEngine.enableVideo()
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        
        let cameraConfig = AgoraCameraCapturerConfiguration()
        cameraConfig.cameraDirection = .rear
        rtcEngine.setCameraCapturerConfiguration(cameraConfig)
        
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
        isLoading = true
        isError = false
        connectionStartView.update(for: .connecting)
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

                // 6. Generate the auth token for REST API authorization
                try await generateAuthToken()

                // 7. Start the agent
                try await startAgent()
                
                await MainActor.run {
                    startupState.markConnected()
                    isLoading = false
                    hideLoadingToast()
                    switchToChatView()
                }
            } catch {
                await MainActor.run {
                    cleanupAfterConnectionFailure()
                    startupState.markFailed()
                    initializationError = error
                    isLoading = false
                    isError = true
                    hideLoadingToast()
                    connectionStartView.update(for: .error)
                    showErrorToast(error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private func cleanupAfterConnectionFailure() {
        rtcJoinContinuation?.resume(throwing: NSError(domain: "joinRTCChannel", code: -999, userInfo: [NSLocalizedDescriptionKey: "RTC join cancelled"]))
        rtcJoinContinuation = nil
        rtcEngine?.leaveChannel()
        convoAIAPI?.unsubscribeMessage(channelName: channel) { _ in }
        rtmEngine?.logout { _, _ in }
        token = ""
        agentToken = ""
        authToken = ""
        agentId = ""
    }

    @MainActor
    private func ensureMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            showErrorToast("Microphone permission is required for voice conversation.")
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
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

    // Auth token for REST API authorization. Generated separately from the agent
    // RTC token so the REST `Authorization: agora token=<authToken>` header carries
    // its own credential (requires APP_CERTIFICATE enabled in the Agora console).
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
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        let result = rtcEngine.joinChannel(byToken: token, channelId: channel, uid: UInt(uid), mediaOptions: options)
        if result != 0 {
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
    private func startAgent() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Align with the working Kotlin curl payload: use the managed preset
            // combo plus inline llm/tts supplemental settings.
            let parameter: [String: Any] = [
                "name": channel,
                "preset": "deepgram_nova_3,openai_gpt_4o_mini,minimax_speech_2_6_turbo",
                "properties": [
                    "channel": channel,
                    "token": agentToken,
                    "agent_rtc_uid": "\(agentUid)",
                    "remote_rtc_uids": ["\(uid)"],
                    "enable_string_uid": false,
                    "idle_timeout": 120,
                    "advanced_features": [
                        "enable_rtm": true
                    ],
                    "asr": [
                        "language": "en"
                    ],
                    "llm": [
                        "system_messages": [
                            ["role": "system", "content": "You are a friendly voice assistant. Keep replies to one or two sentences."]
                        ],
                        "greeting_message": "Hi there! How can I help you today?",
                        "failure_message": "Please wait a moment."
                    ],
                    "tts": [
                        "vendor": "minimax",
                        "params": [
                            "voice_setting": [
                                "voice_id": "English_captivating_female1"
                            ]
                        ]
                    ],
                    "parameters": [
                        "audio_scenario": "chorus",
                        "data_channel": "rtm",
                        "enable_error_message": true,
                        "silence_config": [
                            "action": "speak",
                            "timeout_ms": 0
                        ],
                        "farewell_config": [
                            "graceful_enabled": "false",
                            "graceful_timeout_seconds": 0
                        ]
                    ],
                    "turn_detection": [
                        "mode": "default",
                        "config": [
                            "speech_threshold": "0.6",
                            "start_of_speech": [
                                "model": "vad",
                                "vad_config": [
                                    "interrupt_duration_ms": 500,
                                    "prefix_padding_ms": 800,
                                    "speaking_interrupt_duration_ms": 300
                                ]
                            ],
                            "end_of_speech": [
                                "model": "semantic",
                                "semantic_config": [
                                    "max_wait_ms": 1200,
                                    "pause_state_enabled": false,
                                    "silence_duration_ms": 480
                                ]
                            ]
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
    }
    
    private func switchToConfigView() {
        connectionStartView.isHidden = false
        chatSessionView.setControlsVisible(false)
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
        
        switchToConfigView()
        startupState.reset()
        connectionStartView.update(for: .ready)
        
        transcripts.removeAll()
        chatSessionView.tableView.reloadData()
        isMicMuted = false
        isLoading = false
        isError = false
        initializationError = nil
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
    @objc private func startButtonTapped() {
        guard validateConfiguration() else { return }
        initializeEnginesIfNeeded()

        guard startupState.beginPermissionRequest() else {
            addDebugMessage("Start ignored: session is already connecting")
            return
        }

        Task { @MainActor in
            let granted = await ensureMicrophonePermission()
            guard granted else {
                startupState.markFailed()
                isError = true
                connectionStartView.update(for: .error)
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
    
    @objc private func endCall() {
        let activeAgentId = agentId
        let restAuthToken = authToken
        if !activeAgentId.isEmpty {
            AgentManager.stopAgent(agentId: activeAgentId, token: restAuthToken) { [weak self] error in
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
        let toast = UIView()
        toast.backgroundColor = AppColors.errorRedDark.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 12
        view.addSubview(toast)
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
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
        return transcripts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TranscriptMessageCell.reuseIdentifier, for: indexPath) as! TranscriptMessageCell
        cell.configure(with: transcripts[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - AgoraRtcEngineDelegate
extension ViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        addDebugMessage("Rtc onJoinChannelSuccess, channel:\(channel) uid:\(uid)")
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
    }
    
    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
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
    
    func onAgentError(agentUserId: String, error: ModuleError) {
        addDebugMessage("Agent error: type=\(moduleTypeValue(error.type)), code=\(error.code), msg=\(error.message)")
    }
    
    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.transcripts.firstIndex(where: {
                $0.turnId == transcript.turnId &&
                $0.type.rawValue == transcript.type.rawValue &&
                $0.userId == transcript.userId
            }) {
                self.transcripts[index] = transcript
            } else {
                self.transcripts.append(transcript)
            }
            
            self.chatSessionView.tableView.reloadData()
            
            if !self.transcripts.isEmpty {
                let indexPath = IndexPath(row: self.transcripts.count - 1, section: 0)
                self.chatSessionView.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func onDebugLog(log: String) {
    }
}
