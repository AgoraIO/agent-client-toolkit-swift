# Agora Conversational AI Toolkit for iOS

A client-side toolkit for adding Agora Conversational AI features to iOS applications already using the Agora RTC and RTM SDKs. It runs alongside your existing RTC/RTM integration and adds transcript rendering, agent state tracking, messaging controls, interrupt handling, and latency/error callbacks.

## Install

Choose one package manager to integrate `AgoraAgentClientToolkit`. Do not integrate the same component through CocoaPods and Swift Package Manager at the same time.

### CocoaPods

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'AgoraAgentClientToolkit', '1.0.0'
end
```

If your project uses a custom or private CocoaPods specs repository, add that source at the top of your `Podfile`.

### Swift Package Manager

In Xcode, use `File > Add Package Dependencies...`, enter the SwiftPM package URL, select version `1.0.0` or later, and add the `AgoraAgentClientToolkit` product to your app target.

If you manage dependencies in `Package.swift`, use:

```swift
dependencies: [
    .package(url: "<SwiftPM package URL>/agent-client-toolkit-swift.git", from: "1.0.0")
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

```swift
import AgoraRtcKit
import AgoraRtmKit
import AgoraAgentClientToolkit
```

Create the API with your existing RTC and RTM instances:

```swift
let config = ConversationalAIAPIConfig(
    rtcEngine: rtcEngine,
    rtmEngine: rtmEngine,
    renderMode: .words,
    enableLog: true
)

let convoAIAPI = ConversationalAIAPIImpl(config: config)
convoAIAPI.addHandler(handler: self)
```

Subscribe after RTM login and before starting the agent session:

```swift
convoAIAPI.subscribeMessage(channelName: channelName) { error in
    if let error = error {
        print("Subscription failed: \(error.message)")
    }
}
```

Apply audio settings before joining the RTC channel:

```swift
convoAIAPI.loadAudioSettings()
rtcEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: uid)
```

Handle agent state and transcript updates in your `ConversationalAIAPIEventHandler` implementation:

```swift
func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
    print("Agent state: \(event.state)")
}

func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
    print("Transcript: \(transcript)")
}
```

Send a text message or interrupt the agent:

```swift
let message = TextMessage(text: "Hello")
convoAIAPI.chat(agentUserId: agentUserId, message: message) { error in
    if let error = error {
        print("Send failed: \(error.message)")
    }
}

convoAIAPI.interrupt(agentUserId: agentUserId) { error in
    if let error = error {
        print("Interrupt failed: \(error.message)")
    }
}
```

Unsubscribe and release resources when the session ends:

```swift
convoAIAPI.unsubscribeMessage(channelName: channelName) { _ in }
convoAIAPI.destroy()
```

Full API details are in [AgoraAgentClientToolkit/README.md](./AgoraAgentClientToolkit/README.md).

## Example App

This repository includes a UIKit demo app that shows the complete flow: token generation, RTM login, RTC join, agent startup, transcript display, agent state rendering, mute, and stop.

Run the demo:

```bash
git clone https://github.com/AgoraIO-Conversational-AI/agent-client-toolkit-swift.git
cd agent-client-toolkit-swift
pod install
open VoiceAgent.xcworkspace
```

Copy the sample secrets file and fill in your Agora credentials:

```bash
cp VoiceAgent/Secrets.example.plist VoiceAgent/Secrets.plist
```

Configuration fields:

- `AGORA_APP_ID`: Your Agora App ID.
- `AGORA_APP_CERTIFICATE`: Your Agora App Certificate.

The demo uses Agora-managed keyless mode for ASR, LLM, and TTS model selection, but still requires App ID and App Certificate for token generation and REST API authorization. Production apps should generate tokens and start/stop agents from your own backend instead of calling REST APIs directly from the client.

Before trying the demo, create an Agora project, enable Conversational AI Engine, and enable RTM. See [Enable the service](https://doc.agora.cn/doc/convoai/restful/get-started/enable-service).

## Repository Layout

```text
.
|-- AgoraAgentClientToolkit/
|   |-- AgoraAgentClientToolkit.podspec
|   |-- README.md
|   `-- AgoraAgentClientToolkit/Classes/
|-- VoiceAgent/                 # UIKit demo app
|-- Tests/
|-- Package.swift
|-- Podfile
`-- scripts/
```

## Development

```bash
# Demo app dependencies
pod install

# Validate SwiftPM manifest and build
scripts/verify_spm.sh
```

## Maintainers

For CocoaPods / SwiftPM packaging, see [docs/publishing.md](./docs/publishing.md).

## Resources

- [Agora RTC iOS SDK documentation](https://doc.agora.cn/doc/rtc/ios/landing-page)
- [Agora RTM iOS SDK documentation](https://doc.agora.cn/doc/rtm2/ios/landing-page)
- [Conversational AI RESTful API documentation](https://doc.agora.cn/doc/convoai/restful/landing-page)
- [Conversational AI iOS client component documentation](https://doc.agora.cn/api-ref/convoai/ios/ios-component/overview)
- [Contact Agora Support](https://ticket.agora.cn/)
