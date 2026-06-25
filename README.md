# Agora Conversational AI Toolkit for iOS

A client-side toolkit for adding Agora Conversational AI features to iOS applications already using the Agora RTC and RTM SDKs. It runs alongside your existing RTC/RTM integration and adds transcript rendering, agent state tracking, messaging controls, interrupt handling, and latency/error callbacks.

## Install

Choose one package manager to integrate `AgoraAgentClientToolkit`. Do not integrate the same component through CocoaPods and Swift Package Manager at the same time.

### CocoaPods

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'AgoraAgentClientToolkit', '2.9.0'
end
```

If your project uses a custom or private CocoaPods specs repository, add that source at the top of your `Podfile`.

### Swift Package Manager

In Xcode, use `File > Add Package Dependencies...`, enter `https://github.com/AgoraIO/agent-client-toolkit-swift.git`, select version `2.9.0` or later, and add the `AgoraAgentClientToolkit` product to your app target.

If you manage dependencies in `Package.swift`, use:

```swift
dependencies: [
    .package(url: "https://github.com/AgoraIO/agent-client-toolkit-swift.git", from: "2.9.0")
]
```

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(
                name: "AgoraAgentClientToolkit",
                package: "agent-client-toolkit-swift"
            )
        ]
    )
]
```

## Requirements

- iOS 15.0 or later
- Xcode 14.0 or later
- Agora RTC SDK `4.5.1` or later
- Agora RTM SDK
- Real-time Messaging (RTM) enabled in the Agora Console

SwiftPM dependencies:

- `AgoraRtcEngine_iOS` `4.5.1` or later
- `AgoraRTM_iOS` `2.2.8` or later

CocoaPods dependencies:

- `AgoraRtcEngine_iOS` `4.5.1` or later
- `AgoraRtm/RtmKit` `2.2.3` or later

`AgoraAgentClientToolkit` declares Agora RTC and RTM as package dependencies. Your app only needs to declare RTC/RTM directly if your own code also imports and calls RTC/RTM APIs.

## Quick Start

Create the toolkit API with your existing RTC engine and RTM client:

```swift
import AgoraRtcKit
import AgoraRtmKit
import AgoraAgentClientToolkit

let config = ConversationalAIAPIConfig(
    rtcEngine: rtcEngine,
    rtmEngine: rtmEngine,
    renderMode: .words,
    enableLog: true
)

let convoAIAPI = ConversationalAIAPIImpl(config: config)
convoAIAPI.addHandler(handler: self)
```

Register event callbacks:

```swift
final class ConversationHandler: NSObject, ConversationalAIAPIEventHandler {
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        // Render agent state.
    }

    func onAgentListeningChanged(agentUserId: String, isListening: Bool) {
        // Handle listening state.
    }

    func onAgentThinkingChanged(agentUserId: String, isThinking: Bool) {
        // Handle thinking state.
    }

    func onAgentSpeakingChanged(agentUserId: String, isSpeaking: Bool) {
        // Handle speaking state.
    }

    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        // Handle interruption.
    }

    func onAgentMetrics(agentUserId: String, metrics: Metric) {
        // Observe module latency metrics.
    }

    func onTurnFinished(agentUserId: String, turn: Turn) {
        // Observe completed-turn latency.
    }

    func onAgentError(agentUserId: String, error: ModuleError) {
        // Handle agent-side errors.
    }

    func onMessageError(agentUserId: String, error: MessageError) {
        // Handle message errors.
    }

    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        // Handle message receipts.
    }

    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
        // Handle voiceprint state changes.
    }

    func onUserManualSosEvent(agentUserId: String, event: UserManualSosEvent) {
        // Handle manual SOS result.
    }

    func onUserManualEosEvent(agentUserId: String, event: UserManualEosEvent) {
        // Handle manual EOS result.
    }

    func onAgentManualEosEvent(agentUserId: String, event: AgentManualEosEvent) {
        // Handle automatic EOS in manual mode.
    }

    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        // Render user or agent transcript.
    }

    func onDebugLog(log: String) {
        // Forward debug logs if needed.
    }
}
```

Load audio settings before joining RTC, then subscribe to the RTM message channel after RTC/RTM are ready:

```swift
convoAIAPI.loadAudioSettings()
rtcEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: uid)

convoAIAPI.subscribeMessage(channelName: channelName) { error in
    if let error = error {
        // Handle ConversationalAIAPIError.
        return
    }

    // Start the Conversational AI agent through your app or backend flow.
}
```

See [AgoraAgentClientToolkit/README.md](./AgoraAgentClientToolkit/README.md) for the full component API guide.

## Manual SOS/EOS

If the agent is started with manual turn detection, use the toolkit to publish
manual speech markers through RTM:

```swift
convoAIAPI.manualSOS(agentUserId: agentUserId) { requestId, error in
    // error is nil when RTM publish succeeds.
    // requestId is generated by the toolkit and sent as request_id.
}

convoAIAPI.manualEOS(agentUserId: agentUserId) { requestId, error in
    // error is nil when RTM publish succeeds.
    // requestId is generated by the toolkit and sent as request_id.
}
```

The server processing results are delivered through `onUserManualSosEvent` and
`onUserManualEosEvent`. The toolkit only sends the RTM marker and returns the
generated `requestId`; the host app still owns the agent start request and the
choice of SOS / EOS detection mode.

## Maintainers

For CocoaPods / SwiftPM packaging, see [docs/publishing.md](./docs/publishing.md).

## Resources

- [Agora RTC iOS SDK documentation](https://doc.agora.cn/doc/rtc/ios/landing-page)
- [Agora RTM iOS SDK documentation](https://doc.agora.cn/doc/rtm2/ios/landing-page)
- [Conversational AI RESTful API documentation](https://doc.agora.cn/doc/convoai/restful/landing-page)
- [Conversational AI iOS client component documentation](https://doc.agora.cn/api-ref/convoai/ios/ios-component/overview)
- [Contact Agora Support](https://ticket.agora.cn/)
