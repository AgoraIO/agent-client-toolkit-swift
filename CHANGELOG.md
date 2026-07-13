# Changelog

All notable changes to the iOS Agora Conversational AI Toolkit will be documented in this file.

The format follows Keep a Changelog style. This first public release establishes the compatibility baseline for future iOS releases.

## [Unreleased]

### Deprecated

- Deprecated the aggregate `onAgentStateChanged(...)` callback in favor of independent `onAgentListeningChanged(...)`, `onAgentThinkingChanged(...)`, and `onAgentSpeakingChanged(...)` callbacks. The aggregate callback remains supported, required by the protocol, and continues to be delivered for existing integrations.

## [2.9.0] - 2026-07-02

Initial public release.

### Added

- Published `agent-client-toolkit-swift` as the iOS ConvoAI client toolkit for CocoaPods and Swift Package Manager.
- Added `ConversationalAIAPIImpl` and `ConversationalAIAPIProtocol` for host apps that already manage Agora RTC and RTM engine instances.
- Added transcript parsing and rendering support through `TranscriptRenderMode`, `Transcript`, `TranscriptType`, and `TranscriptStatus`.
- Added agent state callbacks for state, listening, thinking, speaking, interrupt, metrics, turn-finished latency, message receipt, message error, module error, and voiceprint status events.
- Added text and image message publishing through `chat(...)` with `TextMessage` and `ImageMessage`.
- Added direct conversation control APIs: `interrupt(...)`, `manualSOS(...)`, and `manualEOS(...)`.
- Added manual turn result callbacks: `onUserManualSosEvent(...)`, `onUserManualEosEvent(...)`, and `onAgentManualEosEvent(...)`.
- Added maintainer packaging support for Rehoboam CocoaPods and SwiftPM upload input zips.

### Compatibility

| Integration | Add dependency | Swift code |
|-------------|----------------|------------|
| CocoaPods | `pod 'agent-client-toolkit-swift', '2.9.0'` | `import AgoraAgentClientToolkit` |
| SwiftPM | Package URL `https://github.com/AgoraIO/agent-client-toolkit-swift.git`, tag `2.9.0`, product `AgoraAgentClientToolkit` | `import AgoraAgentClientToolkit` |

- Minimum iOS version: 15.0.
- Swift version: 5.0.
- CocoaPods dependencies: `AgoraRtcEngine_iOS >= 4.5.1` and `AgoraRtm/RtmKit >= 2.2.3`.
- SwiftPM dependencies are pinned by the package template to `AgoraRtcEngine_iOS == 4.5.1` and `AgoraRTM_iOS == 2.2.8`.
- Supported public protocol events include `message.metrics`, `turn.finished`, `message.error`, `message.info`, `message.sal_status`, `assistant.transcription`, `user.transcription`, `message.interrupt`, `message.state`, `user.manual_sos.result`, `user.manual_eos.result`, and `assistant.manual_eos.result`.

### Known Limitations

- The toolkit does not create agents, generate app credentials, generate tokens, or own backend start/stop flows. Host apps must provide those flows.
- Shared cross-platform JSON fixture tests are planned but not part of this first release baseline.
