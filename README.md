# Agora Conversational AI Toolkit for iOS

A client-side toolkit for adding Agora Conversational AI features to iOS applications already using the Agora RTC and RTM SDKs. It runs alongside your existing RTC/RTM integration and adds transcript rendering, agent state tracking, messaging controls, interrupt handling, and latency/error callbacks.

## Run the VoiceAgent Demo

The included UIKit demo uses a local Python FastAPI backend powered by
[`agora-agents`](https://github.com/AgoraIO/agora-agents-python). A physical
iPhone is the primary development path because it provides a representative
microphone, speaker, echo cancellation, and network experience.

Prerequisites:

- Python 3.10 or later
- Xcode 16.0 or later for the included VoiceAgent demo
- CocoaPods
- a Mac and physical iPhone running iOS 15.0 or later on the same LAN
- an Agora project with RTC, RTM, and Conversational AI enabled

Install the iOS demo dependencies from the repository root:

```bash
pod install
```

Configure the backend:

```bash
cp server/.env.example server/.env.local
```

Set `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` from your Agora project in
`server/.env.local`, then run from the repository root:

```bash
./scripts/start_backend.sh
```

On first use, the script creates `server/.venv` and installs the pinned Python
dependencies. It starts FastAPI on `0.0.0.0:8001` by default, detects the Mac's
active LAN IP, waits for `/health`, and writes only the backend address to the
Git-ignored `Config/VoiceAgent-Local.xcconfig`.

Set `PORT` in `server/.env.local` or before the command to use another free
port. The script checks the selected port before startup and reports a clear
error instead of overwriting the iOS backend configuration.

Allow incoming Python connections if macOS asks. Then open
`VoiceAgent.xcworkspace`, select your development team and connected iPhone,
and run the `VoiceAgent` scheme.

Do not use `localhost` for a physical iPhone because it resolves to the phone
rather than the Mac. Only Debug builds allow development HTTP for this local
LAN workflow; Release builds keep the arbitrary-load exception disabled.

The demo explicitly uses Agora Fengming STT with managed OpenAI LLM and MiniMax
TTS, so the default path does not require third-party provider keys. The iOS app contains
no App Certificate or provider credentials. The backend generates the user
RTC + RTM token and starts or stops the agent with the pinned
`agora-agents==2.4.1` SDK. This repository does not provide a hosted backend,
shared account, TestFlight build, or maintained prebuilt app. See
[ARCHITECTURE.md](./ARCHITECTURE.md) for the runtime sequence and ownership
boundaries.

## Install

Choose one package manager to integrate `AgoraAgentClientToolkit`. Do not integrate the same component through CocoaPods and Swift Package Manager at the same time.

### CocoaPods

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'agent-client-toolkit-swift', '2.9.0'
end
```

The CocoaPods package name is `agent-client-toolkit-swift`; the Swift module
you import in code remains `AgoraAgentClientToolkit`.

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
- Agora RTC SDK `4.5.1`
- Agora RTM SDK
- Real-time Messaging (RTM) enabled in the Agora Console

SwiftPM dependencies:

- `AgoraRtcEngine_iOS` `4.5.1`
- `AgoraRTM_iOS` `2.2.8`

CocoaPods dependencies:

- `AgoraRtcEngine_iOS` `4.5.1`
- `AgoraRtm/RtmKit` `2.2.3`

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

Register your event handler. A typical handler starts with callbacks like:

```swift
final class ConversationHandler: NSObject, ConversationalAIAPIEventHandler {
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        // Existing aggregate-state integrations remain supported.
    }
    func onAgentListeningChanged(agentUserId: String, isListening: Bool) {}
    func onAgentThinkingChanged(agentUserId: String, isThinking: Bool) {}
    func onAgentSpeakingChanged(agentUserId: String, isSpeaking: Bool) {}

    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        // Render user or agent transcript.
    }

    func onAgentError(agentUserId: String, error: ModuleError) {
        // Handle agent-side errors.
    }

    // Implement the remaining required callbacks for your app.
}
```

The aggregate `onAgentStateChanged` callback is deprecated but remains supported,
required by the protocol, and continues to be delivered. Existing integrations
do not need to migrate. Use the independent callbacks when the UI needs listening,
thinking, and speaking flags that may be active at the same time.

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

## Verification

Run the focused backend and Swift checks from the repository root:

```bash
server/.venv/bin/python -m pytest server/tests -q
./scripts/test_swift.sh
```

These automated checks do not replace physical-device voice validation.

## Release Notes

For release notes, see [CHANGELOG.md](./CHANGELOG.md).

## Maintainers

For CocoaPods / SwiftPM packaging, see [docs/publishing.md](./docs/publishing.md).
