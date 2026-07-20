# VoiceAgent Python Backend Migration

## Status

The code migration described here is implemented for the `VoiceAgent` UIKit
demo. Automated backend, Swift contract, and Simulator build verification are
complete. Physical-device voice and delayed/failed-stop acceptance remain a
manual release gate.

The backend API, Python SDK usage, provider configuration, session settings, and
server tests in this document intentionally match the
`agent-client-toolkit-kotlin` migration. Platform-specific client setup may
differ, but changes to the shared backend contract must be applied to both
repositories.

## Goal

Move token generation and Conversational AI agent lifecycle ownership out of
the iOS demo and into a local Python FastAPI service using the
[`agora-agents`](https://github.com/AgoraIO/agora-agents-python) SDK.

The iOS app continues to own RTC, RTM, UI, and the `AgoraAgentClientToolkit`
lifecycle. The Python service owns Agora credentials, provider configuration,
user token generation, and agent start/stop operations.

```text
iPhone VoiceAgent demo
  -> Python FastAPI service
       -> agora-agents Python SDK
            -> Agora Conversational AI Engine

iPhone VoiceAgent demo
  <-> Agora RTC and RTM
  <-> AgoraAgentClientToolkit callbacks
```

The iOS app must not contain:

- `APP_CERTIFICATE`
- LLM or TTS provider keys
- local AccessToken2 signing code
- an agent RTC token
- a Conversational AI REST authentication token
- direct Agora `/join` or `/leave` URLs
- an `Authorization: agora token=...` REST header

## Developer Experience

Physical devices are the primary development path because Simulator audio does
not provide a representative Conversational AI experience.

1. Make Python 3.10 or later available as `python3`.
2. Connect the Mac and iPhone to the same local network.
3. Copy `server/.env.example` to `server/.env.local`.
4. Fill in the developer's Agora App ID and App Certificate.
5. Run `./scripts/start_backend.sh`.
6. The script starts FastAPI on `0.0.0.0:8001` by default, detects the Mac's
   active LAN IP, waits for the backend health check, and writes the Git-ignored
   `Config/VoiceAgent-Local.xcconfig` backend configuration.
7. Open `VoiceAgent.xcworkspace`, select an Apple development team and connected
   iPhone, and run the `VoiceAgent` scheme.

The generated client configuration exposes:

```text
AGENT_BACKEND_URL=http://<mac-lan-ip>:8001
```

The script preserves unrelated values already present in the generated local
xcconfig. The file remains ignored by Git. The iOS target does not read or
bundle a client credential file.

`localhost` must not be used for the physical-device path because it resolves
to the iPhone itself. Simulator support may remain as an optional build and
basic integration path, but it is not the acceptance path.

The iOS target needs:

- `NSLocalNetworkUsageDescription`
- Debug-only support for local HTTP access
- a Git-ignored local `AGENT_BACKEND_URL` configuration
- an actionable error that includes the attempted backend URL when the Mac
  service cannot be reached

The setup documentation must also tell developers to allow incoming Python
connections through the macOS firewall when prompted.

## Target Ownership Boundaries

### Python Backend

The Python service owns:

- Agora App ID and App Certificate
- RTC + RTM user token generation
- agent RTC credential generation through `agora-agents`
- Conversational AI REST authentication through `agora-agents`
- LLM, TTS, ASR, advanced feature, and turn detection configuration
- agent session start and stop
- active `agentId` to SDK session correlation
- HTTP validation and structured error responses

The App Certificate stays in `server/.env.local`. It must not be returned to the
iOS app, printed in logs, or committed. The managed Pipeline does not require
third-party Provider credentials.

The `agora-agents` dependency must be pinned to an exact release verified by
both demos. Do not use an open-ended minimum version.

### iOS Client

The iOS app continues to own:

- microphone permission
- RTC and RTM client initialization
- RTM login and RTC channel join
- `AgoraAgentClientToolkit` initialization and message subscription
- transcript, latency, agent state, and error rendering
- mute, interrupt, text/image chat, and manual SOS/EOS controls
- immediate local cleanup when the user ends a call

The demo continues to consume `AgoraAgentClientToolkit` through the existing
local CocoaPods dependency. The migration must not modify the toolkit's public
API or copy its source into `VoiceAgent/`.

## Shared Backend API Contract

All successful responses use the following envelope:

```json
{
  "code": 0,
  "data": {},
  "msg": "success"
}
```

Non-success responses use a non-2xx HTTP status and the same envelope with a
non-zero `code`, `data: null`, and a safe `msg`. Clients must validate both the
HTTP status and envelope code and preserve the safe backend message in debug
logs.

### `GET /get_config`

Optional query parameters:

- `channel`: requested channel name
- `uid`: process-stable requested non-zero numeric user UID

The backend generates a valid value when either parameter is absent or invalid.

```json
{
  "code": 0,
  "data": {
    "app_id": "<agora-app-id>",
    "token": "<user-rtc-rtm-token>",
    "uid": "<user-uid>",
    "agent_uid": "<agent-uid>",
    "channel_name": "<channel>"
  },
  "msg": "success"
}
```

The token is the user's unified RTC + RTM token. The RTM login identity and RTC
UID must match the token subject.

### `POST /startAgent`

The client calls this endpoint only after RTC join, RTM login, and toolkit
message subscription have succeeded.

```json
{
  "channelName": "<channel>",
  "agentUid": 10000001,
  "userUid": 1001,
  "startOfSpeechMode": "vad",
  "endOfSpeechMode": "semantic"
}
```

The server validates that the UIDs are positive numeric values and that each
turn detection mode is one of:

- `vad`
- `semantic`
- `manual`

`startOfSpeechMode` maps to
`turn_detection.config.start_of_speech.mode`, and `endOfSpeechMode` maps to
`turn_detection.config.end_of_speech.mode`. The two settings remain
independent. The migration must not add `vad_config` or `semantic_config`.

```json
{
  "code": 0,
  "data": {
    "agent_id": "<runtime-agent-id>",
    "channel_name": "<channel>",
    "status": "started"
  },
  "msg": "success"
}
```

The server preserves these session settings in both repositories:

- `enable_string_uid: false`
- `idle_timeout: 120`
- `advanced_features.enable_sal: false`
- `advanced_features.enable_rtm: true`
- `parameters.data_channel: "rtm"`
- `parameters.enable_metrics: true`
- `parameters.enable_error_message: true`
- `remote_rtc_uids: ["<userUid>"]`

### `POST /stopAgent`

```json
{
  "agentId": "<runtime-agent-id>"
}
```

```json
{
  "code": 0,
  "data": null,
  "msg": "success"
}
```

The backend first stops a tracked SDK session. If the process no longer holds
that session, it falls back to `AsyncAgora.stop_agent(agentId)`. An
already-stopped or expired agent is treated as a successful idempotent stop.

## Managed Pipeline Contract

The Python backend uses the same Agora-managed Pipeline as the Kotlin demo:

| Stage | Provider | Model |
|-------|----------|-------|
| STT | Agora Fengming | default configuration |
| LLM | OpenAI | `gpt-4o-mini` |
| TTS | MiniMax | `speech_2_6_turbo` |

The MiniMax voice is `English_captivating_female1`. `FengmingSTT()` explicitly
serializes ASR as `{"vendor":"fengming"}` without provider parameters. `OpenAI`
and `MiniMaxTTS` are constructed without `api_key`, `key`, or `group_id`. With
`agora-agents==2.4.1`, the SDK serializes the managed LLM/TTS preset:

```text
openai_gpt_4o_mini,minimax_speech_2_6_turbo
```

Only `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` are required credentials.
`AGENT_PROMPT` and `AGENT_GREETING` are optional non-secret copy settings.

## Startup Sequence

```text
User taps Start
  -> request microphone permission
  -> GET /get_config
  -> initialize RTC and RTM with the returned App ID and user UID
  -> initialize AgoraAgentClientToolkit and register its callbacks
  -> loadAudioSettings()
  -> log in to RTM and join RTC with the returned user token
  -> wait for the real RTC didJoinChannel callback
  -> subscribeMessage(channelName)
  -> require successful subscription completion
  -> POST /startAgent with channel, UIDs, and selected SOS/EOS modes
  -> require a non-empty agentId
  -> mark the UI Connected
```

RTC join and RTM login may be sequenced differently from Android when the iOS
code is clearer. Agent start must still wait for both transports and message
subscription.

`POST /startAgent` success means the start request was accepted. Agent state,
transcripts, metrics, and agent-side errors continue to come from toolkit
callbacks rather than locally fabricated state.

Startup failure remains intentionally simple:

```text
show error and debug log
  -> release RTC/RTM/subscription side effects
  -> reset transient session data
  -> return to the normal Start state
```

Keep `SessionStartupState` simple. Do not add backend-specific retry phases,
attempt identifiers, or milestone state unless a concrete runtime bug requires
one.

## Stop and Cleanup Sequence

```text
capture the current agentId
  -> send POST /stopAgent when agentId is non-empty
  -> immediately unsubscribe the toolkit
  -> leave RTC
  -> remove the Toolkit handler and destroy Toolkit
  -> log out of and destroy the RTM client
  -> destroy the RTC engine
  -> clear tokens, channel, UIDs, agentId, transcript, metrics, and UI state
```

Local cleanup must not wait for the Python response or depend on late RTC/RTM
events. A backend stop failure may be logged, but it cannot keep the iOS app in
a connected state.

## Repository Changes

### Shared Python Service

Add the same backend layout and route models to both repositories:

```text
server/
|- src/
|  |- server.py
|  `- agent.py
|- tests/
|- requirements.txt
|- .env.example
`- README.md
```

Also add `scripts/start_backend.sh`. The Python service must:

- create one configured `AsyncAgora` client for the service process
- create `AsyncAgentSession` instances with numeric string agent and remote UIDs
- retain active sessions by `agentId`
- provide stateless stop fallback
- generate combined RTC + RTM user tokens on the server
- apply the shared provider, turn detection, RTM, metrics, and error settings
- avoid logging secrets, tokens, or full authorization headers
- expose a health endpoint used by the startup script

The backend route models and focused Python tests should remain equivalent in
the Android and Swift repositories.

### iOS Client

- change `VoiceAgent/Tools/AgentManager.swift` from a direct Agora REST client
  to the typed local backend client
- update `VoiceAgent/ViewController.swift` to request backend config before
  RTC/RTM setup
- gate `/startAgent` on the successful `subscribeMessage` callback
- store the backend-returned `agentId`
- make backend stop independent from immediate local cleanup
- reduce `VoiceAgent/KeyCenter.swift` and local configuration to
  `AGENT_BACKEND_URL`
- add local-network usage text and Debug-only local HTTP configuration
- remove `VoiceAgent/Dynamickey/TokenGenerator.swift`
- remove `VoiceAgent/Dynamickey/RtcTokenBuilder2.swift`
- remove `VoiceAgent/Dynamickey/AccessToken2.swift`
- remove client-side agent/auth token and provider configuration
- remove direct Agora REST endpoint construction
- update Xcode project membership, README, architecture, examples, and tests in
  the same change

The demo continues consuming `AgoraAgentClientToolkit` through its existing
local CocoaPods dependency. Toolkit source changes are outside this migration.

## Verification

### Python

- configuration validation with missing and valid environment values
- `/get_config` response, token subject, and envelope contract
- `/startAgent` request validation and response envelope
- independent SOS/EOS mode mapping
- pinned-SDK Agent construction with the network session mocked
- managed Provider preset and absence of third-party credential fields
- unique session name and 24-hour token/session credential lifetime
- tracked session stop and stateless stop fallback
- idempotent already-stopped behavior
- structured non-2xx error response shape
- startup script health check and safe local configuration generation

### Swift

- backend URL construction
- typed decoding for all three endpoints
- non-2xx, non-zero envelope code, and malformed response handling
- RTC/RTM readiness and successful subscription gating
- startup failure cleanup and reset to the normal Start state
- delayed or failed backend stop with immediate local cleanup
- Simulator compilation and focused unit tests
- Release configuration does not package client secrets or enable development
  HTTP exceptions

### Physical Device Acceptance

The migration is complete only after an iPhone and Mac on the same LAN verify:

- the iPhone reaches the detected LAN URL
- microphone and local-network permissions succeed
- RTM login and RTC join use the expected UID
- message subscription completes before agent start
- the agent joins and produces audible TTS
- user and agent transcripts render from toolkit callbacks
- latency metrics and agent state still render
- text, image URL, mute, and interrupt work
- configured manual SOS/EOS actions work
- Stop returns the app to its initial state even when the backend response is
  delayed or fails

A Simulator build or unit-test pass is build evidence, not proof of the complete
voice experience.

## Completion Criteria

The migration is complete when:

- the iOS app no longer directly starts or stops agents through Agora REST
- no App Certificate, provider secret, agent token, or REST auth token is
  packaged in the app
- the shared backend contract matches the Android repository
- a developer can start the Python service and run the demo on a physical device
- the existing client feature set remains available
- Swift and Python automated tests pass
- a physical-device voice round trip and delayed/failed stop have been verified

## Non-Goals

This migration does not include:

- a hosted or production backend
- shared Agora credentials
- exposing the local backend to the public network
- TestFlight or a maintained prebuilt app
- making the Simulator the primary experience path
- video capture, publication, subscription, or rendering
- a UI framework migration
- toolkit source or public API changes
- a more complex startup state machine
