# Conversational AI Quickstart iOS Swift — AI Assistant Guide

## How to Use This Project

This is a complete, runnable iOS demo for real-time voice conversation with an AI agent.

- If you don't have an existing project, use this project directly. Modify it based on user requirements.
- If you already have a project, refer to the key parts of this project (connection flow, UI structure, AgoraAgentClientToolkit integration) and adapt them into the existing codebase.

## How to Switch AI Providers

The default RESTful startup flow uses explicit ASR / LLM / TTS blocks. If you need to switch providers, the change is made in `ViewController.swift` → `startAgent()` and `KeyCenter.swift`:

1. Update the `ASR_*`, `LLM_*`, and `TTS_*` values in local secrets or build settings
2. If the selected mode requires extra vendor-specific fields, add only the minimum documented supplemental config under `properties.asr`, `properties.llm`, or `properties.tts`

Supported vendors for STT/TTS/LLM change over time. Refer to the [Start Agent API documentation](https://doc.agora.cn/doc/convoai/restful/convoai/operations/start-agent) for the up-to-date list of supported vendors and their required parameters.

## Project Overview

Conversational AI Quickstart — iOS real-time voice conversation client built with UIKit.

The client directly calls Agora RESTful API to start/stop Agent, authenticated via HTTP token (`Authorization: agora token=<token>`). The current implementation aligns with the Kotlin demo payload and sends explicit `properties.asr`, `properties.llm`, and `properties.tts` blocks.

Current quickstart scope is limited to voice session startup, startup-time SOS / EOS turn detection selection, transcript display, state rendering, manual SOS / EOS trigger buttons when enabled, mute, and stop. It does not expose text or image message sending UI.

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
| RTM SDK | Agora RTM SDK (`AgoraRtm/RtmKit` 2.2.3+) |
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
- Turn detection flow: the top-right settings button selects independent SOS / EOS detection modes before startup. Both settings support `VAD`, `Semantic`, and `Manual`.
- Manual turn flow: when SOS or EOS detection is set to `Manual`, the chat view shows the corresponding manual trigger button after connection and logs publish/result callbacks.
- Random channel name format is `channel_swift_<6-digit-random>`

### AgentManager

- `startAgent()`: POST `/join`, request body carries session fields plus explicit ASR / LLM / TTS config
  - `properties.asr` carries `vendor`, `params.api_key`, and `params.model`
  - `properties.llm` carries `url`, `api_key`, `params.model`, `greeting_message`, and `failure_message`
  - `properties.tts` carries `vendor`, `params.key`, `params.model_id`, `params.voice_id`, and `params.sample_rate`
  - `properties.turn_detection` uses `mode: "default"` plus independent `start_of_speech.mode` and `end_of_speech.mode` values selected before startup
  - Manual SOS / EOS mode sends only `mode: "manual"` for the selected side. Do not include `vad_config` or `semantic_config` for manual mode.
  - Advanced features: `enable_aivad: false`, `enable_bhvs: true`, `enable_sal: false`, `enable_rtm: true`
  - Remote UIDs: `remote_rtc_uids: ["<currentUserUid>"]`
- `stopAgent()`: POST `/agents/{agentId}/leave`
- Authentication: `Authorization: agora token=<authToken>`

### NetworkManager (Demo Only)

- Generates RTC/RTM tokens via `TOOLBOX_SERVER_HOST` + `/v2/token/generate`
- Sends `appId`, `channelName`, `uid`, `types` (1=RTC, 2=RTM), `expire`, `src`, and `ts` in POST body
- Sends `appCertificate` only when `APP_CERTIFICATE` is configured
- Returns a unified token usable for both RTC and RTM
- Also wraps generic JSON HTTP POST/GET requests used by `AgentManager`
- Demo only — production must use your own backend for token generation

### AgoraAgentClientToolkit

- Provides the `ConversationalAIAPI` types through the local Pod dependency
- Wraps RTM message subscription/parsing
- The quickstart currently reacts to:
  - `onAgentStateChanged`
  - `onTranscriptUpdated`
  - `onAgentError`
  - `onUserManualSosEvent`
  - `onUserManualEosEvent`
  - `onAgentManualEosEvent`
- Render mode is `.words`
- Initialized with both RTC and RTM engines after SDK setup

## Configuration

### Configuration Flow

```
KeyCenter.swift → ViewController / AgentManager / NetworkManager
```

Static credentials are resolved by `KeyCenter.swift` from `Info.plist` build settings first, then from local `VoiceAgent/Secrets.plist`. `VoiceAgent/Secrets.plist` is ignored by Git and must not be committed. For CI or internal builds, inject `APP_ID` and optional `APP_CERTIFICATE` as Xcode build settings. `TOOLBOX_SERVER_HOST` can also be injected to configure the demo token service.

### Configuration Fields (KeyCenter.swift)

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| `APP_ID` | Agora App ID | ✅ | — |
| `APP_CERTIFICATE` | Agora App Certificate. Sent to the demo token service only when configured. | ❌ | empty |
| `TOOLBOX_SERVER_HOST` | Demo token service host | ❌ | empty |
| `ASR_VENDOR` | ASR provider name | ❌ | `soniox` |
| `ASR_API_KEY` | ASR provider key | ❌ | empty |
| `ASR_MODEL` | ASR model | ❌ | `stt-rt-preview-v2` |
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
3. Fill in `APP_CERTIFICATE` only when your token service requires it
4. Fill in `TOOLBOX_SERVER_HOST` to point to the demo token service

### Build-Time Validation

There is no automatic build-time validation in this target. Missing or invalid values in `VoiceAgent/Secrets.plist` or injected build settings usually fail at runtime during token generation, SDK initialization, or REST calls.
`KeyCenter` ignores unresolved build setting placeholders and sample placeholder values, and `ViewController` blocks startup when required values are missing.

## API Endpoints

Client directly calls Agora REST API (Demo mode):

| Endpoint | Method | Auth Header | Description |
|----------|--------|-------------|-------------|
| `api-test.agora.io/api/conversational-ai-agent/v2/projects/{appId}/join` | POST | `Authorization: agora token=<authToken>` | Start Agent |
| `api-test.agora.io/api/conversational-ai-agent/v2/projects/{appId}/agents/{agentId}/leave` | POST | `Authorization: agora token=<authToken>` | Stop Agent |

Token generated via Demo service (must be replaced with your own backend in production):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `{TOOLBOX_SERVER_HOST}/v2/token/generate` | POST | Generate RTC/RTM Token. Sends `appCertificate` only when configured. |

If you need to point to a different backend, change the URL strings in `Tools/AgentManager.swift` and `Tools/NetworkManager.swift`.

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
      "enable_aivad": false,
      "enable_bhvs": true,
      "enable_sal": false,
      "enable_rtm": true
    },
    "asr": {
      "vendor": "soniox",
      "params": {
        "api_key": "<ASR_API_KEY>",
        "model": "stt-rt-preview-v2"
      }
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
      "output_audio_codec": "OPUSFB",
      "audio_scenario": "default",
      "transcript": {
        "enable": true,
        "protocol_version": "v2",
        "enable_words": false
      },
      "data_channel": "rtm"
    },
    "turn_detection": {
      "mode": "default",
      "config": {
        "speech_threshold": 0.6,
        "start_of_speech": {
          "mode": "vad",
          "vad_config": {
            "interrupt_duration_ms": 500,
            "speaking_interrupt_duration_ms": 300,
            "prefix_padding_ms": 800
          }
        },
        "end_of_speech": {
          "mode": "semantic",
          "semantic_config": {
            "silence_duration_ms": 480,
            "max_wait_ms": 1200,
            "pause_state_enabled": false
          }
        }
      }
    }
  }
}
```

### Token Generation Request Body

```json
{
  "appId": "<APP_ID>",
  "appCertificate": "<APP_CERTIFICATE, optional>",
  "channelName": "<channel>",
  "uid": "<uid>",
  "types": [1, 2],
  "expire": 86400,
  "src": "iOS",
  "ts": "<timestamp_ms>"
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
7. Generate `authToken` for REST API authorization
8. Call `AgentManager.startAgent(parameter, authToken)` to start Agent
9. AgoraAgentClientToolkit receives agent state / transcript events via RTM → `ViewController` updates UI
10. If a manual turn capability was enabled at startup, user taps SOS / EOS → `manualSOS(...)` / `manualEOS(...)` publishes the marker and logs the later server result callback
11. User taps Stop → unsubscribe ConvoAI → stop agent → leave RTC → logout RTM → clear local state

## How to Change Request Parameters

The agent start request body is built in `ViewController.swift` → `startAgent()` as a nested dictionary. Key sections:

| Section | What it controls | Where in the dictionary |
|---------|------------------|-------------------------|
| `asr` | Speech-to-text vendor, language, credentials | `properties.asr` |
| `llm` | LLM endpoint, model, system prompt, greeting/failure messages | `properties.llm` |
| `tts` | Text-to-speech vendor, voice, speed | `properties.tts` |
| `parameters` | Data channel (`rtm`), error message toggle | `properties.parameters` |
| `turn_detection` | SOS / EOS detection mode and mode-specific config | `properties.turn_detection` |
| `advanced_features` | RTM enable flag | `properties.advanced_features` |
| Top-level | Channel name, agent UID, idle timeout, token | `properties.*` |

To modify request parameters: edit the `parameter` dictionary in `startAgent()`. Static values should stay in `KeyCenter.swift`; structural changes should be made in the dictionary itself.

## Key Constraints

1. **Demo Mode**: Config is resolved by `KeyCenter.swift`; the client directly calls REST API and the demo token service.
2. **Production**: Sensitive info (`APP_CERTIFICATE`, LLM/STT/TTS keys) must move to your backend; the client should only fetch token/session info from your own server.
3. **Token Generation**: `NetworkManager.generateToken()` is demo-only; production must use your own server.
4. **Resource Cleanup**: RTC leave, RTM logout, ConvoAI unsubscribe, and local UI state reset all happen during `endCall()`.
5. **Permissions**: The app requires microphone access for voice conversation.
6. **AgoraAgentClientToolkit is read-only for the sample app**: The app must use it through the `AgoraAgentClientToolkit` Pod dependency. Do not copy the component source into `VoiceAgent/` or modify it from the sample app.
7. **Server Overrides**: If you point the app to a local backend, use the host machine IP, not `localhost` or `127.0.0.1`, when testing on a real device.

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
build/internal-cocoapods/AgoraAgentClientToolkit-<version>-<timestamp>/AgoraAgentClientToolkit-<version>.zip
build/internal-spm/AgoraAgentClientToolkit-<version>-rehoboam-<timestamp>/AgoraAgentClientToolkit-<version>-rehoboam-input.zip
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
