# Conversational AI Quickstart iOS Swift - AI Assistant Guide

## How to Use This Project

This repository contains the `AgoraAgentClientToolkit` package and a complete
UIKit voice-agent demo. Use the demo directly when starting a project, or copy
its RTC/RTM, subscription, callback, and local-backend integration patterns
into an existing app.

The primary demo path is a physical iPhone connected to the same LAN as the Mac
running the local Python backend. The repository does not maintain a hosted
backend, shared credentials, TestFlight build, or prebuilt app.

## Project Overview

The iOS client owns RTC, RTM, Toolkit, UI, and immediate local cleanup. The
FastAPI service under `server/` owns all secrets, combined user token
generation, and agent lifecycle operations through `agora-agents==2.4.1`.

Current demo scope includes startup-time independent SOS/EOS selection,
transcript and latency rendering, agent state, interrupt, text and image URL
messages, manual SOS/EOS, mute, and stop.

## Tech Stack

| Category | Technology |
|----------|------------|
| iOS language/UI | Swift, UIKit, programmatic views, SnapKit |
| iOS networking | async `URLSession` + Codable |
| RTC | `AgoraRtcEngine_iOS` 4.5.1 |
| RTM | `AgoraRtm/RtmKit` 2.2.3 |
| Toolkit | local CocoaPods pod `agent-client-toolkit-swift` |
| Backend | Python 3.10+, FastAPI, `agora-agents==2.4.1` |
| Providers | Agora Fengming STT + managed OpenAI LLM + MiniMax TTS |

## Core Modules

### ViewController

- Owns the single-screen UIKit flow and session state.
- Requests `/get_config` before creating RTC or RTM.
- Initializes Toolkit with the returned App ID and UIDs.
- Calls `loadAudioSettings()` before RTC join.
- Waits for RTM login, the real RTC `didJoinChannel` callback, and successful
  `subscribeMessage` completion before `/startAgent`.
- Opens the connected UI only after the backend returns a non-empty `agentId`.
- Uses one locally generated non-zero user UID for the app process; every
  session still gets a new channel and backend-generated Agent UID.
- Receives agent state, transcript, latency, messages, and manual turn results
  only from `AgoraAgentClientToolkit` callbacks.
- Sends backend stop asynchronously while performing local cleanup immediately.

### AgentManager

- Typed local-backend client for:
  - `GET /get_config`
  - `POST /startAgent`
  - `POST /stopAgent`
- Validates HTTP status, the shared response envelope, required data, and
  non-empty `agentId`.
- Sends only channel, numeric UIDs, and selected SOS/EOS modes for agent start.
- Must not construct Agora REST endpoints or authorization headers.

### NetworkManager

- Uses structured `URLQueryItem` query encoding and Codable request/response
  bodies.
- Propagates transport failures with the attempted backend URL.
- Extracts safe backend `msg`, `reason`, or `detail` values on non-2xx responses.
- Keeps Debug cURL output redacted.
- Must not log response tokens or full secret-bearing payloads.

### Python Backend

- `server/src/server.py` defines the FastAPI envelope and routes.
- `server/src/agent.py` validates environment configuration, creates one
  `AsyncAgora` client, builds the Fengming/OpenAI/MiniMax Agent, and
  tracks active `AsyncAgentSession` values by `agentId`.
- User config contains a combined RTC + RTM token generated on the server.
- Agent start uses numeric string UIDs, `enable_string_uid: false`, an idle
  timeout of 120, RTM data channel, metrics/errors, SAL disabled, and RTM enabled.
- Shared numeric UIDs stay within `1...2_147_483_647` so the backend contract is
  also safe for the Android quickstart.
- Stop uses a tracked session first and `AsyncAgora.stop_agent()` as an
  idempotent stateless fallback.
- Fengming ASR is explicit and has no provider parameters. OpenAI and MiniMax
  constructors do not receive provider keys. Request-shape tests lock the ASR
  vendor, managed LLM/TTS preset, and absence of third-party credentials.

### AgoraAgentClientToolkit

- Continue consuming the local Pod and importing `AgoraAgentClientToolkit`.
- Do not copy its source into `VoiceAgent/` or modify Toolkit public APIs from
  the sample app.
- Render mode remains `.words`.
- Cleanup must unsubscribe, remove the event handler, destroy Toolkit, log out
  and destroy the RTM client, and destroy the RTC engine.

## Startup Review Guardrails

- `loadAudioSettings()` runs before RTC `joinChannel`.
- Agent start waits for RTC joined, RTM logged in, and Toolkit message
  subscription success.
- Turn detection is selected before startup. SOS and EOS independently support
  `vad`, `semantic`, and `manual`.
- Backend turn detection sends only the selected `mode` for each side. Do not
  add `vad_config` or `semantic_config`.
- `SessionStartupState` stays simple; do not add attempt IDs, retry phases, or
  milestone models without a proven runtime bug.
- `/startAgent` acceptance does not fabricate agent state or transcript data.
- `endCall()` does not wait for `/stopAgent`; backend failure may be logged but
  cannot retain connected UI or Agora resources.

## Configuration

### Developer Flow

```text
server/.env.local
  -> FastAPI / agora-agents

scripts/start_backend.sh
  -> Config/VoiceAgent-Local.xcconfig
  -> Info.plist AGENT_BACKEND_URL
  -> KeyCenter / AgentManager
```

1. Make Python 3.10 or later available as `python3`.
2. Copy `server/.env.example` to `server/.env.local`.
3. Fill in the developer's Agora App ID and App Certificate.
4. Connect the Mac and iPhone to the same LAN.
5. Run `./scripts/start_backend.sh`.
6. Allow incoming Python connections if macOS prompts.
7. Open `VoiceAgent.xcworkspace` and run on the connected iPhone.

The script listens on `0.0.0.0:8001` by default, detects the active Mac LAN IP,
waits for `/health`, and writes the ignored
`Config/VoiceAgent-Local.xcconfig`. Never use `localhost` or `127.0.0.1` for the
physical-device backend URL.

The client configuration contains only `AGENT_BACKEND_URL`. Source plist and
xcconfig files are excluded from target resources. Debug permits development
HTTP; Release does not include the ATS arbitrary-load exception.

### Backend Environment

| Field | Purpose |
|-------|---------|
| `AGORA_APP_ID` | Agora project App ID |
| `AGORA_APP_CERTIFICATE` | Server-side token signing |
| `AGENT_PROMPT` | Optional system prompt |
| `AGENT_GREETING` | Optional initial greeting |
| `PORT` | Optional local FastAPI port; defaults to `8001` |

To switch providers, change `server/src/agent.py`, `server/.env.example`, and
the focused server request-shape tests together. Non-managed or custom Providers
may require third-party credentials; keep them in the Python backend and never
move them or vendor payload construction into Swift.

## Backend API

All responses use `{ "code": ..., "data": ..., "msg": ... }`. Errors use a
non-2xx status, non-zero code, `data: null`, and a safe message.

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Startup-script readiness check |
| `GET /get_config` | App ID, user RTC+RTM token, UIDs, channel |
| `POST /startAgent` | Start SDK session after iOS transport/subscription readiness |
| `POST /stopAgent` | Idempotently stop tracked or untracked agent |

`POST /startAgent` request:

```json
{
  "channelName": "channel_swift_123456",
  "agentUid": 10000001,
  "userUid": 1001,
  "startOfSpeechMode": "vad",
  "endOfSpeechMode": "semantic"
}
```

The iOS app must never contain or construct an App Certificate, provider key,
agent RTC token, Conversational AI REST token, direct Agora `/join` or `/leave`
URL, or `Authorization: agora token=...` header.

## Verification

```bash
server/.venv/bin/python -m pytest server/tests -q
./scripts/test_swift.sh
xcodebuild -workspace VoiceAgent.xcworkspace -scheme VoiceAgent \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Simulator build success is not physical voice acceptance. Before release, use
a real iPhone on the same LAN to verify audible TTS, both transcripts, latency,
state, chat, image URL, interrupt, mute, configured manual SOS/EOS, and Stop
behavior when the backend is delayed or unavailable.

## Key Constraints

1. All secrets stay in `server/.env.local`; never print, commit, or return them.
2. The local backend is a developer quickstart, not a production deployment.
3. `AgoraAgentClientToolkit` remains a read-only dependency for the sample.
4. Resource cleanup never depends on late RTC/RTM events or backend completion.
5. Physical-device testing uses the Mac LAN IP, not localhost.
6. Provider changes must remain server-side and update request-shape tests.

## Internal Rehoboam Release

Rehoboam is the internal release platform for both CocoaPods and SwiftPM. Do not document Rehoboam, Jenkins download URLs, or internal release requests in public-facing README files.

Release strategy:

- Publish only formal SemVer versions, for example `2.9.0`; do not publish prerelease or SNAPSHOT versions.
- Complete package plus sample or clean-app validation before formal publication.
- If a problem is found after the final version is published, do not overwrite or delete that version; publish a new version such as `2.9.1`.

To prepare the Rehoboam upload zips:

```bash
VERSION=2.9.0 scripts/build_rehoboam_cocoapods_input_zip.sh
VERSION=2.9.0 scripts/build_rehoboam_swiftpm_input_zip.sh
```

The generated zips are:

```text
build/internal-cocoapods/agora-agent-client-toolkit-<version>-<timestamp>/agora-agent-client-toolkit-<version>-cocoapods-rehoboam-input.zip
build/internal-spm/agora-agent-client-toolkit-<version>-swiftpm-<timestamp>/agora-agent-client-toolkit-<version>-swiftpm-rehoboam-input.zip
```

Use the same explicit `VERSION` for CocoaPods and SwiftPM when they are released together. The scripts require a formal SemVer version and reject prerelease or SNAPSHOT versions.

## File Naming

- Swift source files: `PascalCase.swift`
- UIKit view classes: `*View.swift`, `*Cell.swift`, `ViewController.swift`
- Utility files: `*Manager.swift`, `KeyCenter.swift`
- Python files: `snake_case.py`

## Documentation Navigation

| Document | Description |
|----------|-------------|
| `AGENTS.md` | Development rules and project constraints |
| `ARCHITECTURE.md` | Runtime ownership and lifecycle |
| `README.md` | Package integration and demo quick start |
| `docs/voiceagent-python-backend-migration.md` | Migration contract and acceptance checklist |
