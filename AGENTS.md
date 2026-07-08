# Conversational AI Quickstart iOS Swift — AI Assistant Guide

## How to Use This Project

This is a complete, runnable iOS demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, AgoraAgentClientToolkit integration) and adapt them into the existing codebase.

## How to Switch AI Providers

The default RESTful startup flow uses server default ASR plus explicit LLM / TTS blocks. If you need to switch LLM or TTS providers, the change is made in `ViewController.swift` → `startAgent()` and `KeyCenter.swift`:

1. Update the `LLM_*` and `TTS_*` values in local secrets or build settings
2. If the selected mode requires extra vendor-specific fields, add only the minimum documented supplemental config under `properties.llm` or `properties.tts`

Supported vendors for STT/TTS/LLM change over time. Refer to the [Start Agent API documentation](https://doc.agora.cn/doc/convoai/restful/convoai/operations/start-agent) for the up-to-date list of supported vendors and their required parameters.

## Project Overview

Conversational AI Quickstart — iOS real-time voice conversation client built with UIKit.

The client directly calls Agora RESTful API to start/stop Agent, authenticated via HTTP token (`Authorization: agora token=<token>`). The current implementation aligns with the Kotlin demo payload, uses server default ASR, and sends explicit `properties.llm` and `properties.tts` blocks.

Current quickstart scope is limited to voice session startup, startup-time SOS / EOS turn detection selection, transcript and latency display, state rendering, interrupt, text / image URL message sending, manual SOS / EOS trigger buttons when enabled, mute, and stop.

## Tech Stack

| Category | Technology |
|----------|------------|
| Language | Swift |
| UI Framework | UIKit + programmatic views + SnapKit |
| App Structure | `AppDelegate` + `SceneDelegate` + single `ViewController` |
| Build Tool | Xcode + CocoaPods |
| State Management | `ViewController` instance state |
| Networking | `URLSession` |
| RTC SDK | Agora RTC SDK (`AgoraRtcEngine_iOS` 4.5.1) |
| RTM SDK | Agora RTM SDK (`AgoraRtm/RtmKit` 2.2.3) |
| AgoraAgentClientToolkit | Swift module from local CocoaPods pod `agent-client-toolkit-swift`; do not modify from the sample app |

For runtime structure, see `ARCHITECTURE.md`. For entry files, see `README.md`.

## Core Modules

### ViewController

- Main controller for the whole demo
- Manages `ConnectionStartView`, `ChatSessionView`, `ChatMessageInputPanelView`, and the always-visible debug log panel
- Holds session state directly as instance properties:
  - `channel`, `token`, `agentToken`, `authToken`, `agentId`
  - `uid`, `agentUid`
  - `transcriptItems`, `pendingTurnLatencyMetrics`, `isLatencyMetricsVisible`
  - `isMicMuted`, `currentAgentState`, `startupState`
- Auto flow: generate user token → login RTM → join RTC → subscribe ConvoAI → generate agent token → generate auth token → start agent
- Turn detection flow: the top-right settings button selects independent SOS / EOS detection modes before startup. Both settings support `VAD`, `Semantic`, and `Manual`.
- Chat message flow: the chat button opens a connected-only input panel that sends text messages or image URLs through `ConversationalAIAPI.chat(...)` and logs publish, receipt, and error callbacks.
- Manual turn flow: when SOS or EOS detection is set to `Manual`, the chat view shows the corresponding manual trigger button after connection and logs publish/result callbacks.
- Random channel name format is `channel_swift_<6-digit-random>`

### AgentManager

- `startAgent()`: POST `/join`, request body carries session fields plus explicit LLM / TTS config
  - ASR uses the server default; the demo does not send a `properties.asr` block
  - `properties.llm` carries `url`, `api_key`, `params.model`, `greeting_message`, and `failure_message`
  - `properties.tts` carries `vendor`, `params.key`, `params.model_id`, `params.voice_id`, and `params.sample_rate`
  - `properties.turn_detection` uses `mode: "default"` plus independent `start_of_speech.mode` and `end_of_speech.mode` values selected before startup
  - Turn detection sends only the selected `mode` for each side. Do not include `vad_config` or `semantic_config`.
  - Advanced features: `enable_sal: false`, `enable_rtm: true`
  - Remote UIDs: `remote_rtc_uids: ["<currentUserUid>"]`
- `stopAgent()`: POST `/agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<authToken>`

### TokenGenerator (Demo Only)

- Generates unified RTC + RTM AccessToken2 locally from `APP_CERTIFICATE`
- Returns a unified token usable for RTC join, RTM login, and ConvoAI REST auth
- Mirrors the Kotlin demo structure: `TokenGenerator` validates config and calls `RtcTokenBuilder2`, while `AccessToken2` handles signing and binary packing
- Demo only — production must use your own backend for token generation and must not ship `APP_CERTIFICATE` in the app

### NetworkManager

- Wraps generic JSON HTTP POST/GET requests used by `AgentManager`
- Must not contain local token generation logic

### AgoraAgentClientToolkit

- Provides the `ConversationalAIAPI` types through the local CocoaPods pod `agent-client-toolkit-swift` and Swift module `AgoraAgentClientToolkit`
- Wraps RTM message subscription/parsing
- The quickstart currently reacts to:
  - `onAgentStateChanged`
  - `onTranscriptUpdated`
  - `onTurnFinished`
  - `onAgentError`
  - `onMessageError`
  - `onMessageReceiptUpdated`
  - `onUserManualSosEvent`
  - `onUserManualEosEvent`
  - `onAgentManualEosEvent`
- Render mode is `.words`
- Initialized with both RTC and RTM engines after SDK setup

## Startup Review Guardrails

For AI / PR reviews, use the current demo flow and business rules as the source of truth. Do not propose generic startup refactors unless they fix a concrete violation.

- `loadAudioSettings()` must run before RTC `joinChannel`.
- RTM login, RTC join, message subscription, and token generation may be sequenced differently from Kotlin when the platform code is clearer, but `AgentManager.startAgent(...)` must wait until RTC joined, RTM message subscribed, `agentToken` ready, `authToken` ready, and startup-time SOS / EOS modes selected.
- ConvoAI message subscription must complete before `AgentManager.startAgent(...)`.
- Connected UI is opened only after `/join` returns a non-empty `agentId`. Agent state, transcript, and agent-side errors must still come from AgoraAgentClientToolkit callbacks, not local fabrication.
- `endCall()` owns both the stop request and local cleanup path. Local state, `agentId`, RTC, RTM, and message subscription cleanup must not depend on late RTM events.
- Keep `SessionStartupState` simple. Do not add extra milestone models, login-state layers, or attempt identifiers beyond the existing flow unless there is a proven business bug.

## Configuration

### Configuration Flow

```
KeyCenter.swift → ViewController / AgentManager / NetworkManager / TokenGenerator
```

Static credentials are resolved by `KeyCenter.swift` from `Info.plist` build settings first, then from local `VoiceAgent/Secrets.plist`. `VoiceAgent/Secrets.plist` is ignored by Git and must not be committed. For CI or internal builds, inject `APP_ID` and `APP_CERTIFICATE` as Xcode build settings.

### Configuration Fields (KeyCenter.swift)

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `APP_ID` | Agora App ID | ✅ | — |
| `APP_CERTIFICATE` | Agora App Certificate. Required only for the local demo token generator; production apps must keep this on a backend. | ✅ | — |
| `LLM_URL` | OpenAI-compatible LLM endpoint | ❌ | `https://api.groq.com/openai/v1/chat/completions` |
| `LLM_API_KEY` | LLM API key | ❌ | empty |
| `LLM_MODEL` | LLM model | ❌ | `llama-3.3-70b-versatile` |
| `TTS_VENDOR` | TTS provider name | ❌ | `elevenlabs` |
| `TTS_KEY` | TTS provider key | ❌ | empty |
| `TTS_MODEL_ID` | TTS model ID | ❌ | `eleven_flash_v2_5` |
| `TTS_VOICE_ID` | TTS voice ID | ❌ | empty |
| `TTS_SAMPLE_RATE` | TTS sample rate | ❌ | `44100` |

### Demo Token Service

Make sure to:
1. Copy `VoiceAgent/Secrets.example.plist` to `VoiceAgent/Secrets.plist`
2. Fill in `APP_ID` in the local secrets file
3. Fill in `APP_CERTIFICATE` (required for local token generation)

### Build-Time Validation

There is no automatic build-time validation in this target. Missing or invalid values in `VoiceAgent/Secrets.plist` or injected build settings usually fail at runtime during token generation, SDK initialization, or REST calls.
`KeyCenter` ignores unresolved build setting placeholders and sample placeholder values, and `ViewController` blocks startup when required values are missing.

## API Endpoints

Client directly calls Agora REST API (Demo mode):

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api.agora.io/api/conversational-ai-agent/v2/projects/{appId}/join` | POST | `Authorization: agora token=<authToken>` | Start Agent |
| `api.agora.io/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<authToken>` | Stop Agent |

Token generation in Demo mode (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| Local `TokenGenerator` AccessToken2 builder | — | Uses `APP_CERTIFICATE` to create a unified RTC + RTM token |

If you need to point to a different backend, change the URL strings in `Tools/AgentManager.swift`.

### Start Agent Request Body Structure

```json
{
  "name": "<channel>",
  "properties": {
    "channel": "<channel>",
    "token": "<agentToken>",
    "agent_rtc_uid": "<agentUid>",
    "remote_rtc_uids": ["<currentUserUid>"],
    "enable_string_uid": false,
    "idle_timeout": 120,
    "advanced_features": {
      "enable_sal": false,
      "enable_rtm": true
    },
    "llm": {
      "url": "https://api.groq.com/openai/v1/chat/completions",
      "api_key": "",
      "params": {
        "model": "llama-3.3-70b-versatile"
      },
      "greeting_message": "hello man, I am an AI robot, I can do anything for you",
      "failure_message": "Sorry, I don't know how to answer your question"
    },
    "tts": {
      "vendor": "elevenlabs",
      "params": {
        "key": "<TTS_KEY>",
        "model_id": "eleven_flash_v2_5",
        "voice_id": "<TTS_VOICE_ID>",
        "sample_rate": 44100
      }
    },
    "parameters": {
      "enable_metrics": true,
      "enable_error_message": true,
      "data_channel": "rtm"
    },
    "turn_detection": {
      "mode": "default",
      "config": {
        "start_of_speech": {
          "mode": "vad"
        },
        "end_of_speech": {
          "mode": "semantic"
        }
      }
    }
  }
}
```

### Local AccessToken2 Token Structure

The demo `TokenGenerator` builds an AccessToken2 locally using:

- `APP_ID` and `APP_CERTIFICATE` from `KeyCenter`
- `channelName` (the session channel)
- `uid` (numeric user or agent UID)
- RTC privileges: join channel, publish audio/video/data streams
- RTM privileges: RTM login
- 24-hour expiry
- Output format: `"007"` prefix + Base64(zlib-deflate(token payload))
- Token payload contains HMAC-SHA256 signature over signing info (appId, issueTs, expire, salt, services)

## Data Flow

```
User Action → ViewController → Agora SDK (RTC/RTM)
                  ↓
        AgoraAgentClientToolkit callbacks
                  ↓
        ViewController state update
                  ↓
             UIKit view update
```

## Event Flow

1. User taps Start → `channel` is generated in `ViewController`
2. Generate `userToken` for the current channel and current `uid`
3. Login RTM with `userToken`
4. Join RTC channel with `userToken`
5. Subscribe to ConvoAI RTM messages for `channel`
6. Generate `agentToken` for `agentUid`
7. Generate `authToken` for REST API authorization
8. Call `AgentManager.startAgent(parameter, authToken)` to start Agent
9. AgoraAgentClientToolkit receives agent state / transcript events via RTM → `ViewController` updates UI
10. User taps Chat after connection → enters text or an image URL → `chat(...)` publishes a `TextMessage` or `ImageMessage` and later message receipt/error callbacks update the debug log
11. If a manual turn capability was enabled at startup, user taps SOS / EOS → `manualSOS(...)` / `manualEOS(...)` publishes the marker and logs the later server result callback
12. User taps Stop → unsubscribe ConvoAI → stop agent → leave RTC → logout RTM → clear local state

## How to Change Request Parameters

The agent start request body is built in `ViewController.swift` → `startAgent()` as a nested dictionary. Key sections:

| Section | What it controls | Where in the dictionary |
|---------|------------------|-------------------------|
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor, voice, speed | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `turn_detection` | SOS / EOS detection mode | `properties.turn_detection` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit the `parameter` dictionary in `startAgent()`. Static LLM / TTS values should stay in `KeyCenter.swift`; ASR uses the server default in the current sample, and structural changes should be made in the dictionary itself.

## Key Constraints

1. **APP_CERTIFICATE is required by the local demo token flow**: This project uses HTTP token auth for REST API. The demo `TokenGenerator` uses `APP_CERTIFICATE` for local AccessToken2 generation.
2. **Demo Mode**: Config is resolved by `KeyCenter.swift`; the client directly calls REST API.
3. **Production**: Sensitive info (`APP_CERTIFICATE`, LLM/STT/TTS keys) must move to your backend; the client should only fetch token/session info from your own server and must not embed `APP_CERTIFICATE`.
4. **Token Generation**: `TokenGenerator.generateTokensAsync()` is demo-only; production must use your own server and must not embed `APP_CERTIFICATE`.
5. **Resource Cleanup**: RTC leave, RTM logout, ConvoAI unsubscribe, and local UI state reset all happen during `endCall()`.
6. **Permissions**: The app requires microphone access for voice conversation.
7. **AgoraAgentClientToolkit is read-only for the sample app**: The app must use it through the `agent-client-toolkit-swift` Pod dependency and import the `AgoraAgentClientToolkit` Swift module. Do not copy the component source into `VoiceAgent/` or modify it from the sample app.
8. **Server Overrides**: If you point the app to a local backend, use the host machine IP, not `localhost` or `127.0.0.1`, when testing on a real device.

## Internal Rehoboam Release

Rehoboam is the internal release platform for both CocoaPods and SwiftPM. Do not document Rehoboam, Jenkins download URLs, or internal release requests in public-facing README files.

Release strategy:

- Do not use the final release version as the first validation artifact.
- Package and publish an RC first, for example `2.9.0-rc.1`.
- Validate the RC through Rehoboam platform validation plus sample or clean-app consumption.
- If fixes are needed before formal publish, drop the staging deployment and publish the next RC.
- Publish the final version, for example `2.9.0`, only after the RC passes.
- If a problem is found after the final version is published, do not overwrite or delete that version; publish a new version such as `2.9.1`.

To prepare the Rehoboam upload zips:

```bash
VERSION=2.9.0-rc.1 scripts/build_rehoboam_cocoapods_input_zip.sh
VERSION=2.9.0-rc.1 scripts/build_rehoboam_swiftpm_input_zip.sh
```

The generated zips are:

```text
build/internal-cocoapods/agora-agent-client-toolkit-<version>-<timestamp>/agora-agent-client-toolkit-<version>-cocoapods-rehoboam-input.zip
build/internal-spm/agora-agent-client-toolkit-<version>-swiftpm-<timestamp>/agora-agent-client-toolkit-<version>-swiftpm-rehoboam-input.zip
```

Use the same explicit `VERSION` for CocoaPods and SwiftPM when they are released together. The scripts require a non-SNAPSHOT version.

## File Naming

- Swift source files: `PascalCase.swift`
- UIKit view classes: `*View.swift`, `*Cell.swift`, `ViewController.swift`
- Utility files: `*Manager.swift`, `KeyCenter.swift`

## Documentation Navigation

| Document | Description |
|----------|-------------|
| AGENTS.md | AI Agent development guidelines and project constraints |
| ARCHITECTURE.md | Technical architecture details (modules, state ownership, runtime flow) |
| README.md | Quick start and usage guide |
