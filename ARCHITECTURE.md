# Architecture — Conversational AI Quickstart iOS Swift

## Architecture Overview

This quickstart is a single-screen voice conversation demo built with UIKit and programmatic views.

Current scope:

- Start Agent
- RTC join + RTM login
- Startup-time selection for independent SOS / EOS turn detection
- Real-time transcript rendering
- Real-time latency display with a visibility toggle
- Agent status rendering
- Interrupt
- Text message and image URL publishing
- Manual SOS / EOS trigger buttons shown by selected detection modes
- Mute / unmute
- Stop Agent and cleanup

Out of scope for this quickstart:

- Multi-screen business flow
- Backend-owned token / agent startup flow

## Page Layout

The page is intentionally single-screen and is organized into these regions:

- debug log panel at the top
- startup-time turn detection summary and settings button
- start view before connection
- transcript list and latency toggle after connection
- capability panel for manual SOS / EOS actions when enabled
- agent status view
- mute / chat / stop controls
- bottom input panel for connected-only text and image URL messages

## Project Structure

```text
ios-swift/
├── Podfile
├── VoiceAgent/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── ViewController.swift
│   ├── KeyCenter.swift
│   ├── AppColors.swift
│   ├── ManualTurnDemoUI.swift
│   ├── TurnDetectionMode.swift
│   ├── Chat/
│   │   ├── ConnectionStartView.swift
│   │   ├── ChatSessionView.swift
│   │   ├── AgentStateView.swift
│   │   └── TranscriptMessageCell.swift
│   ├── Tools/
│   │   ├── AgentManager.swift
│   │   └── NetworkManager.swift
│   ├── Dynamickey/
│   │   ├── TokenGenerator.swift
│   │   ├── RtcTokenBuilder2.swift
│   │   └── AccessToken2.swift
└── VoiceAgent.xcworkspace

AgoraAgentClientToolkit is consumed through the local Pod dependency declared in
`Podfile`.
```

## Runtime Shape

```text
ViewController /
RTC / RTM / ConversationalAIAPI /
TokenGenerator / NetworkManager / AgentManager
```

`ConversationalAIAPI` types are provided by the `AgoraAgentClientToolkit` Pod,
which parses RTM payloads and emits agent / transcript callbacks.

## Connection Flow (User taps Start Agent)

```text
Tap Start Agent
  → generate channel
  → generate user token
  → login RTM
  → join RTC
  → subscribe RTM channel
  → generate agentToken
  → generate authToken
  → POST /join with explicit ASR / LLM / TTS config and selected `turn_detection`
  → save agentId
  → switch to chat view
```

iOS Swift-specific conventions:

- `uid` and `agentUid` are random integers and do not conflict
- `channel` format is `channel_swift_<6-digit-random>`
- REST auth header is `Authorization: agora token=<authToken>`

## Transcript And Message Data Flow

```text
RTM message
  → AgoraAgentClientToolkit
  → ViewController.onTranscriptUpdated(...)
  → transcriptItems update
  → ChatSessionView table reload
```

The current UI renders:

- agent transcript on the left
- user transcript on the right
- optional turn latency metrics on agent transcript rows

Chat message publishing:

```text
Tap Chat
  → ChatMessageInputPanelView
  → ViewController.sendTextMessage(...) / sendImageUrlMessage(...)
  → ConversationalAIAPI.chat(...)
  → onMessageReceiptUpdated(...) / onMessageError(...)
  → debug log update
```

## UI State Rendering

```text
startupState             → start button, loading toast, connected controls
currentAgentState        → AgentStateView status
transcriptItems          → transcript table content
pending latency metrics  → real-time data labels on agent rows
debugLogList             → top log panel
isMicMuted               → mic button state
sos/eos detection        → turn detection label + manual capability panel
chat input visibility    → bottom text / image URL input panel
```

Turn detection is selected before startup. `SOS` controls
`properties.turn_detection.config.start_of_speech.mode`; `EOS`
controls `properties.turn_detection.config.end_of_speech.mode`. Both support
`vad`, `semantic`, and `manual`. When a selected mode is `manual`, the matching
SOS or EOS button appears after the connection is established.

Manual button flow:

```text
Tap SOS / EOS
  → ConversationalAIAPI.manualSOS(...) / manualEOS(...)
  → RTM publish with custom type user.manual_sos / user.manual_eos
  → server result event
  → ViewController.onUserManualSosEvent(...) / onUserManualEosEvent(...)
  → debug log update
```

## Token Flow

The quickstart generates three token roles through `TokenGenerator`. In demo
mode, `TokenGenerator` uses local AccessToken2 generation from
`APP_CERTIFICATE`:

| Token | Purpose | Usage |
|-------|---------|-------|
| `token` | User RTC join + RTM login | `joinChannel()` / `loginRTM()` |
| `agentToken` | Agent RTC join credential | Request body `properties.token` |
| `authToken` | REST API authentication | `Authorization: agora token=<authToken>` |

Notes:

- all three tokens are unified RTC + RTM tokens
- `token` uses the current `channel` so RTC join and RTM login are bound to the session channel
- `agentToken` and `authToken` are generated after RTC / RTM are both ready
- production should replace demo-side token generation with a backend and must not embed `APP_CERTIFICATE`

## Agent Lifecycle

```text
IDLE
  → LISTENING
  → THINKING
  → SPEAKING
  → LISTENING
```

Additional behavior:

- `unknown` is the initial UI state before agent events arrive
- tapping Stop unsubscribes RTM, stops the Agent, leaves RTC, logs out RTM, and resets UI state

## Config Contract

```text
KeyCenter.swift
  → ViewController / AgentManager / NetworkManager / TokenGenerator
```

Required fields:

- `APP_ID`
- `APP_CERTIFICATE`

Local credentials should be stored in `VoiceAgent/Secrets.plist`, copied from
`VoiceAgent/Secrets.example.plist`. The local secrets file is ignored by Git.
CI or internal builds can inject the same values through Xcode build settings
named `APP_ID` and `APP_CERTIFICATE`.

Default demo ASR / LLM / TTS values are resolved by `KeyCenter.swift`:

- ASR: `ASR_VENDOR`, `ASR_API_KEY`, `ASR_MODEL`
- LLM: `LLM_URL`, `LLM_API_KEY`, `LLM_MODEL`
- TTS: `TTS_VENDOR`, `TTS_KEY`, `TTS_MODEL_ID`, `TTS_VOICE_ID`, `TTS_SAMPLE_RATE`

## Constraints

- This is a demo; token generation and agent startup are client-side for convenience
- Production should move token generation and REST startup to a backend and must not embed `APP_CERTIFICATE`
- `AgoraAgentClientToolkit` should be consumed through Pod dependency and not
  copied into `VoiceAgent/`
