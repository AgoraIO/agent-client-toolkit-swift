# Conversational AI Quickstart iOS Swift — AI Assistant Guide

## How to Use This Project

This is a complete, runnable iOS demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, AgoraAgentClientToolkit integration) and adapt them into the existing codebase.

## How to Switch AI Providers

The default RESTful startup flow uses an Agora-managed preset. If you need to switch providers, the change is made in `ViewController.swift` → `startAgent()`:

1. Update the top-level `preset` string for the managed ASR / LLM / TTS combination
2. If the selected mode requires extra vendor-specific fields, add only the minimum documented supplemental config under `properties`

Supported vendors for STT/TTS/LLM change over time. Refer to the [Start Agent API documentation](https://doc.agora.cn/doc/convoai/restful/convoai/operations/start-agent) for the up-to-date list of supported vendors and their required parameters.

## Project Overview

Conversational AI Quickstart — iOS real-time voice conversation client built with UIKit.

The client directly calls Agora RESTful API to start/stop Agent, authenticated via HTTP token (`Authorization: agora token=<token>`). The current implementation aligns with the working Kotlin curl payload and uses a top-level managed `preset` plus inline `properties.llm` / `properties.tts` supplemental config in the default flow. This auth mode requires APP_CERTIFICATE to be enabled.

Current quickstart scope is limited to voice session startup, transcript display, state rendering, mute, and stop. It does not expose text or image message sending UI.

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
| RTM SDK | Agora RTM SDK (`AgoraRtm/RtmKit` 2.2.6) |
| AgoraAgentClientToolkit | Local Pod component, do not modify from the sample app |

For runtime structure, see `ARCHITECTURE.md`. For entry files, see `README.md`.

## Core Modules

### ViewController

- Main controller for the whole demo
- Manages `ConnectionStartView`, `ChatSessionView`, and the always-visible debug log panel
- Holds session state directly as instance properties:
  - `channel`, `token`, `agentToken`, `agentId`
  - `uid`, `agentUid`
  - `transcripts`, `isMicMuted`, `currentAgentState`
- Auto flow: generate user token → login RTM → join RTC → subscribe ConvoAI → generate agent token → start agent
- Random channel name format is `channel_swift_<6-digit-random>`

### AgentManager

- `startAgent()`: POST `/join`, request body carries session fields plus a top-level managed preset
  - Preset: `deepgram_nova_3,openai_gpt_4o_mini,minimax_speech_2_6_turbo` (ASR + LLM + TTS, all Agora-managed)
  - `properties.asr` / `properties.llm` / `properties.tts` carry only supplemental settings
  - Advanced features: `enable_rtm: true`, `enable_string_uid: false`, `idle_timeout: 120`
  - Remote UIDs: `remote_rtc_uids: ["<currentUserUid>"]`
- `stopAgent()`: POST `/agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<authToken>`

### NetworkManager (Demo Only)

- Generates RTC/RTM tokens via demo service at `https://service.apprtc.cn/toolbox/v2/token/generate`
- Sends `appId`, `appCertificate`, `channelName`, `uid`, `types` (1=RTC, 2=RTM) in POST body
- Returns a unified token usable for both RTC and RTM
- **Requires APP_CERTIFICATE**: the demo token service needs `appCertificate` to generate valid tokens
- Also wraps generic JSON HTTP POST/GET requests used by `AgentManager`
- Demo only — production must use your own backend for token generation

### AgoraAgentClientToolkit

- Provides the `ConversationalAIAPI` types through the local Pod dependency
- Wraps RTM message subscription/parsing
- The quickstart currently reacts to:
  - `onAgentStateChanged`
  - `onTranscriptUpdated`
  - `onAgentError`
- Render mode is `.words`
- Initialized with both RTC and RTM engines after SDK setup

## Configuration

### Configuration Flow

```
KeyCenter.swift → ViewController / AgentManager / NetworkManager
```

Static credentials are resolved by `KeyCenter.swift` from `Info.plist` build settings first, then from local `VoiceAgent/Secrets.plist`. `VoiceAgent/Secrets.plist` is ignored by Git and must not be committed. For CI or internal builds, inject `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` as Xcode build settings. `ViewController` uses the resolved values to build the start-agent payload, while `NetworkManager` uses the resolved App ID and App Certificate for demo token generation.

### Configuration Fields (KeyCenter.swift)

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `AGORA_APP_ID` | Agora App ID | ✅ | — |
| `AGORA_APP_CERTIFICATE` | Agora App Certificate (must be enabled) | ✅ | — |

### APP_CERTIFICATE Must Be Enabled

This project uses HTTP token auth (`Authorization: agora token=<token>`) for REST API calls, and the demo token service sends `appCertificate` to generate valid RTC/RTM tokens. Both require the App Certificate to be enabled.

Make sure to:
1. Enable the primary certificate for your App ID in the [Agora Console](https://console.agora.cn/)
2. Copy `VoiceAgent/Secrets.example.plist` to `VoiceAgent/Secrets.plist`
3. Fill in `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in the local secrets file

### Build-Time Validation

There is no automatic build-time validation in this target. Missing or invalid values in `VoiceAgent/Secrets.plist` or injected build settings usually fail at runtime during token generation, SDK initialization, or REST calls.
`KeyCenter` ignores unresolved build setting placeholders and sample placeholder values, and `ViewController` blocks startup when required values are missing.

## API Endpoints

Client directly calls Agora REST API (Demo mode):

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api.agora.io/api/conversational-ai-agent/v2/projects/{appId}/join` | POST | `Authorization: agora token=<authToken>` | Start Agent |
| `api.agora.io/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<authToken>` | Stop Agent |

Token generated via Demo service (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `service.apprtc.cn/toolbox/v2/token/generate` | POST | Generate RTC/RTM Token (requires appId + appCertificate) |

If you need to point to a different backend, change the URL strings in `Tools/AgentManager.swift` and `Tools/NetworkManager.swift`.

### Start Agent Request Body Structure

```json
{
  "name": "<channel>",
  "preset": "deepgram_nova_3,openai_gpt_4o_mini,minimax_speech_2_6_turbo",
  "properties": {
    "channel": "<channel>",
    "token": "<agentToken>",
    "agent_rtc_uid": "<agentUid>",
    "remote_rtc_uids": ["<currentUserUid>"],
    "enable_string_uid": false,
    "idle_timeout": 120,
    "advanced_features": { "enable_rtm": true },
    "asr": {
      "language": "en"
    },
    "llm": {
      "system_messages": [{ "role": "system", "content": "You are a friendly voice assistant. Keep replies to one or two sentences." }],
      "greeting_message": "Hi there! How can I help you today?",
      "failure_message": "Please wait a moment."
    },
    "tts": {
      "vendor": "minimax",
      "params": {
        "voice_setting": {
          "voice_id": "English_captivating_female1"
        }
      }
    },
    "parameters": { "audio_scenario": "chorus", "data_channel": "rtm", "enable_error_message": true }
  }
}
```

### Token Generation Request Body

```json
{
  "appId": "<AGORA_APP_ID>",
  "appCertificate": "<AGORA_APP_CERTIFICATE>",
  "channelName": "<channel>",
  "uid": "<uid>",
  "types": [1, 2],
  "expire": 86400,
  "src": "iOS",
  "ts": 0
}
```

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
7. Call `AgentManager.startAgent(parameter, userToken)` to start Agent
8. AgoraAgentClientToolkit receives agent state / transcript events via RTM → `ViewController` updates UI
9. User taps Stop → unsubscribe ConvoAI → stop agent → leave RTC → logout RTM → clear local state

## How to Change Request Parameters

The agent start request body is built in `ViewController.swift` → `startAgent()` as a nested dictionary. Key sections:

| Section | What it controls | Where in the dictionary |
|---------|------------------|-------------------------|
| `preset` | Managed ASR / LLM / TTS combination | top-level `preset` |
| `asr` | Speech-to-text vendor, language, credentials | `properties.asr` |
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor, voice, speed | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit the `parameter` dictionary in `startAgent()`. Static values should stay in `KeyCenter.swift`; structural changes should be made in the dictionary itself.

## Key Constraints

1. **APP_CERTIFICATE required**: This project uses token-based REST auth and demo token generation. `AGORA_APP_CERTIFICATE` must be enabled in the Agora console and configured through ignored local secrets or build settings.
2. **Demo Mode**: Config is resolved by `KeyCenter.swift`; the client directly calls REST API and the demo token service.
3. **Production**: Sensitive info (`appCertificate`, LLM/STT/TTS keys) must move to your backend; the client should only fetch token/session info from your own server.
4. **Token Generation**: `NetworkManager.generateToken()` is demo-only; production must use your own server.
5. **Resource Cleanup**: RTC leave, RTM logout, ConvoAI unsubscribe, and local UI state reset all happen during `endCall()`.
6. **Permissions**: The app requires microphone access for voice conversation.
7. **AgoraAgentClientToolkit is read-only for the sample app**: The app must use it through the `AgoraAgentClientToolkit` Pod dependency. Do not copy the component source into `VoiceAgent/` or modify it from the sample app.
8. **Server Overrides**: If you point the app to a local backend, use the host machine IP, not `localhost` or `127.0.0.1`, when testing on a real device.

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
