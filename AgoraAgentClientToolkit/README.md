# AgoraAgentClientToolkit

iOS library for consuming Agora Conversational AI RTM events, tracking agent state, rendering transcripts, and sending RTM-based messages to an agent.

The library is designed to sit on top of an app's existing Agora RTC and RTM setup. It does not create RTC/RTM clients, generate tokens, join RTC channels, or start the Conversational AI agent.

## Install

See the root [README.md](../README.md) for CocoaPods and Swift Package Manager setup.

## Prerequisites

| Requirement | Version |
|-------------|---------|
| iOS deployment target | 15.0+ |
| Agora RTC SDK | `AgoraRtcEngine_iOS` 4.5.1 |
| Agora RTM SDK for CocoaPods | `AgoraRtm/RtmKit` 2.2.3 |
| Agora RTM SDK for SwiftPM | `AgoraRTM_iOS` 2.2.8 |
| Swift | 5.0+ |

The host app owns:

- RTC engine creation and lifecycle
- RTM client creation, login, logout, and token renewal
- token generation
- joining and leaving RTC channels
- starting and stopping the Conversational AI agent

Before using this component, make sure RTM is enabled in the Agora Console and the RTM client is logged in.

## Quick Start

```swift
let conversationalAIAPI = ConversationalAIAPIImpl(
    config: ConversationalAIAPIConfig(
        rtcEngine: rtcEngine,
        rtmEngine: rtmEngine,
        renderMode: .words,
        enableLog: true,
        enableRenderModeFallback: true
    )
)
```

Register event callbacks:

```swift
final class ConversationHandler: NSObject, ConversationalAIAPIEventHandler {
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        // Render agent state.
    }

    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        // Render user or agent transcript.
    }

    func onAgentError(agentUserId: String, error: ModuleError) {
        // Handle agent-side errors.
    }

    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {}
    func onAgentMetrics(agentUserId: String, metrics: Metric) {}
    func onMessageError(agentUserId: String, error: MessageError) {}
    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {}
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {}
    func onUserManualSosEvent(agentUserId: String, event: UserManualSosEvent) {}
    func onUserManualEosEvent(agentUserId: String, event: UserManualEosEvent) {}
    func onAgentManualEosEvent(agentUserId: String, event: AgentManualEosEvent) {}
    func onDebugLog(log: String) {}
}

let handler = ConversationHandler()
conversationalAIAPI.addHandler(handler: handler)
```

Load audio settings before joining RTC, then subscribe to the RTM message channel after RTC/RTM are ready:

```swift
conversationalAIAPI.loadAudioSettings()
rtcEngine.joinChannel(byToken: token, channelId: channelName, uid: uid, mediaOptions: options)

conversationalAIAPI.subscribeMessage(channelName: channelName) { error in
    if let error = error {
        // Handle ConversationalAIAPIError.
        return
    }

    // Start the Conversational AI agent through your app or backend flow.
}
```

After subscription succeeds, the component calls `whoNow` once to backfill current Presence states so the latest agent status is not missed if it was published before subscription.

## Configuration Reference

`ConversationalAIAPIConfig` fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `rtcEngine` | `AgoraRtcEngineKit` | Yes | Existing Agora RTC engine owned by the host app |
| `rtmEngine` | `AgoraRtmClientKit` | Yes | Existing Agora RTM client owned by the host app |
| `renderMode` | `TranscriptRenderMode` | Yes | `.words` or `.text` |
| `enableLog` | `Bool` | No | Enables toolkit logs written through the RTC SDK log path; defaults to `true` |
| `enableRenderModeFallback` | `Bool` | No | Falls back from `.words` to `.text` when word-level transcript data is unavailable; defaults to `true` |

## API Reference

### `ConversationalAIAPIImpl`

Create an instance with `ConversationalAIAPIConfig`:

```swift
let api: ConversationalAIAPI = ConversationalAIAPIImpl(config: config)
```

### `ConversationalAIAPI`

```swift
func addHandler(handler: ConversationalAIAPIEventHandler)
func removeHandler(handler: ConversationalAIAPIEventHandler)
func subscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
func unsubscribeMessage(channelName: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
func chat(agentUserId: String, message: ChatMessage, completion: @escaping (ConversationalAIAPIError?) -> Void)
func interrupt(agentUserId: String, completion: @escaping (ConversationalAIAPIError?) -> Void)
func manualSOS(agentUserId: String, completion: @escaping (String, ConversationalAIAPIError?) -> Void)
func manualEOS(agentUserId: String, completion: @escaping (String, ConversationalAIAPIError?) -> Void)
func loadAudioSettings()
func loadAudioSettings(secnario: AgoraAudioScenario)
func destroy()
```

`manualSOS(...)` and `manualEOS(...)` are optional protocol methods for custom
`ConversationalAIAPI` implementations. `ConversationalAIAPIImpl` provides both
methods.

`loadAudioSettings()` must be called before every `AgoraRtcEngineKit.joinChannel` call.

For Avatar mode, use:

```swift
conversationalAIAPI.loadAudioSettings(secnario: .default)
```

For standard voice mode, use:

```swift
conversationalAIAPI.loadAudioSettings()
```

## Events

Implement `ConversationalAIAPIEventHandler` to receive callbacks.

| Callback | Payload | Description |
|----------|---------|-------------|
| `onAgentStateChanged` | `StateChangeEvent` | Agent lifecycle state changed |
| `onAgentListeningChanged` | `Bool` | Convenience callback for listening state |
| `onAgentThinkingChanged` | `Bool` | Convenience callback for thinking state |
| `onAgentSpeakingChanged` | `Bool` | Convenience callback for speaking state |
| `onAgentInterrupted` | `InterruptEvent` | Agent turn was interrupted |
| `onAgentMetrics` | `Metric` | Module latency or performance metric |
| `onTurnFinished` | `Turn` | Completed-turn latency data |
| `onAgentError` | `ModuleError` | Agent module error |
| `onMessageError` | `MessageError` | Chat message delivery or processing error |
| `onMessageReceiptUpdated` | `MessageReceipt` | Chat message receipt update |
| `onAgentVoiceprintStateChanged` | `VoiceprintStateChangeEvent` | Voiceprint status update |
| `onUserManualSosEvent` | `UserManualSosEvent` | Server result for `manualSOS(...)` |
| `onUserManualEosEvent` | `UserManualEosEvent` | Server result for `manualEOS(...)` |
| `onAgentManualEosEvent` | `AgentManualEosEvent` | Server automatic EOS notification in manual mode |
| `onTranscriptUpdated` | `Transcript` | User or agent transcript update |
| `onDebugLog` | `String` | Toolkit debug log |

Some events require corresponding fields in the agent start request:

| Event | Required agent start parameter |
|-------|--------------------------------|
| Agent state and message events | `advanced_features.enable_rtm: true` and `parameters.data_channel: "rtm"` |
| Agent metrics | `parameters.enable_metrics: true` |
| Agent errors | `parameters.enable_error_message: true` |

All event callbacks are dispatched on the main thread.

## Transcript Rendering

`TranscriptRenderMode.words` renders word-level transcripts when the server provides word timing data. If word-level data is unavailable and `enableRenderModeFallback` is `true`, the library falls back to `TranscriptRenderMode.text`.

`onTranscriptUpdated()` may be called frequently. If your UI stores a transcript list, deduplicate or update by `turnId`, `type`, and `userId`.

Important transcript values:

| Type | Values |
|------|--------|
| `TranscriptRenderMode` | `.words`, `.text` |
| `TranscriptType` | `.agent`, `.user` |
| `TranscriptStatus` | `.inprogress`, `.end`, `.interrupted` |

## Sending Messages

Send text:

```swift
let message = TextMessage(
    priority: .interrupt,
    interruptable: true,
    text: "Hello"
)

conversationalAIAPI.chat(agentUserId: agentUserId, message: message) { error in
    // error is nil on success.
}
```

Send image:

```swift
let message = ImageMessage(
    uuid: "image-1",
    url: "https://example.com/image.jpg"
)

conversationalAIAPI.chat(agentUserId: agentUserId, message: message) { error in
    // error is nil on success.
}
```

Use `url` for large images. `base64` must stay within RTM message size limits.

Interrupt the agent:

```swift
conversationalAIAPI.interrupt(agentUserId: agentUserId) { error in
    // error is nil on success.
}
```

Trigger manual start/end of speech:

```swift
conversationalAIAPI.manualSOS(agentUserId: agentUserId) { requestId, error in
    // error is nil when RTM publish succeeds.
    // requestId is generated by the toolkit and sent as request_id.
    // Server processing result arrives in onUserManualSosEvent.
}

conversationalAIAPI.manualEOS(agentUserId: agentUserId) { requestId, error in
    // error is nil when RTM publish succeeds.
    // requestId is generated by the toolkit and sent as request_id.
    // Server processing result arrives in onUserManualEosEvent.
}
```

The toolkit generates a non-empty `requestId` for every manual request and
returns it from the publish completion so callers can correlate the publish
attempt with the later server result callback. The toolkit does not decide
whether manual mode is currently allowed; server validation results are reported
through manual turn callbacks.

## Important Types

| Type | Purpose |
|------|---------|
| `ConversationalAIAPIConfig` | Supplies `AgoraRtcEngineKit`, `AgoraRtmClientKit`, transcript render mode, and logging options |
| `ConversationalAIAPI` | Main API for handlers, subscription, chat, interrupt, manual SOS/EOS, audio settings, and destroy |
| `ConversationalAIAPIEventHandler` | Main callback interface for state, transcripts, errors, metrics, receipts, manual turn results, and debug logs |
| `Transcript` | UI-ready transcript payload with turn ID, user ID, text, status, type, and render mode |
| `AgentState` | Agent lifecycle state: `.idle`, `.silent`, `.listening`, `.thinking`, `.speaking`, `.unknown` |
| `UserManualSosEvent` | Result for a user-triggered manual SOS request |
| `UserManualEosEvent` | Result for a user-triggered manual EOS request |
| `AgentManualEosEvent` | Automatic EOS notification in manual mode |
| `ConversationalAIAPIError` | Error wrapper for RTM, RTC, and unknown failures |
| `Priority` | Chat priority: `.interrupt`, `.append`, `.ignore` |

## Lifecycle Checklist

1. Create and configure `AgoraRtcEngineKit`.
2. Create and log in `AgoraRtmClientKit`.
3. Create `ConversationalAIAPIImpl`.
4. Register `ConversationalAIAPIEventHandler`.
5. Call `loadAudioSettings()` before `joinChannel`.
6. Join RTC.
7. Call `subscribeMessage(channelName)`.
8. Start the Conversational AI agent through your app or backend flow.
9. Render callbacks from `ConversationalAIAPIEventHandler`.
10. On exit, call `unsubscribeMessage()`, leave RTC, remove handlers, and call `destroy()`.

## Troubleshooting

### Events are not firing

Check that the agent start request enables RTM events:

```json
{
  "properties": {
    "advanced_features": {
      "enable_rtm": true
    },
    "parameters": {
      "data_channel": "rtm"
    }
  }
}
```

Metrics and agent errors require extra parameters:

```json
{
  "properties": {
    "parameters": {
      "enable_metrics": true,
      "enable_error_message": true
    }
  }
}
```

### Word-level transcripts are empty

Use `TranscriptRenderMode.text`, or keep `enableRenderModeFallback = true` so the toolkit can fall back to text rendering when word-level data is unavailable.

### Audio behavior is incorrect

Make sure `loadAudioSettings()` is called before each RTC `joinChannel` call. Use `.default` for Avatar mode and the default `.aiClient` path for standard voice mode.

### Messages or interrupts fail

Check that RTM is logged in, `subscribeMessage(channelName)` succeeded, and `agentUserId` is the agent RTM user ID.

## File Structure

- [ConversationalAIAPI.swift](./AgoraAgentClientToolkit/Classes/ConversationalAIAPI.swift) - API interfaces and related data structures and enums
- [ConversationalAIAPIImpl.swift](./AgoraAgentClientToolkit/Classes/ConversationalAIAPIImpl.swift) - main implementation
- [Transcript/](./AgoraAgentClientToolkit/Classes/Transcript/) - transcript parsing and rendering support

## Support

- Get help through [Agora Support](https://ticket.agora.cn/form?type_id=&sdk_product=&sdk_platform=&sdk_version=&current=0&project_id=&call_id=&channel_name=) for intelligent customer service or contact technical support staff
