# Architecture - Conversational AI Quickstart iOS Swift

## Overview

The quickstart is a single-screen UIKit voice client plus a local Python
backend. The iOS app owns RTC, RTM, Toolkit callbacks, UI, and immediate local
cleanup. The backend owns credentials, token generation, provider settings,
and the Conversational AI agent lifecycle through `agora-agents`.

```text
iPhone VoiceAgent
  -> local FastAPI backend -> agora-agents -> Agora Conversational AI
  <-> Agora RTC / RTM
  <-> AgoraAgentClientToolkit callbacks
```

The primary development path is a physical iPhone and Mac on the same LAN.
There is no hosted service, TestFlight build, or shared credential set.

## Project Structure

```text
agent-client-toolkit-swift/
|- VoiceAgent/
|  |- ViewController.swift
|  |- KeyCenter.swift
|  |- SessionStartupState.swift
|  |- Chat/
|  `- Tools/
|     |- AgentManager.swift
|     `- NetworkManager.swift
|- server/
|  |- src/
|  |  |- agent.py
|  |  `- server.py
|  |- tests/
|  |- .env.example
|  `- requirements.txt
|- scripts/
|  |- start_backend.sh
|  `- test_swift.sh
`- VoiceAgent.xcworkspace
```

The app consumes `AgoraAgentClientToolkit` through the local CocoaPods
dependency. The sample does not copy or modify Toolkit source.

## Ownership

### iOS Client

- microphone and local-network permissions
- `GET /get_config`, `POST /startAgent`, and `POST /stopAgent`
- RTC and RTM initialization from backend-returned App ID, UID, and user token
- `ConversationalAIAPI` creation, subscription, callbacks, and destruction
- transcript, latency, state, chat, interrupt, manual SOS/EOS, and mute UI
- local teardown that does not wait for the backend stop response

The iOS bundle contains only `AGENT_BACKEND_URL`. It does not contain an App
Certificate, provider keys, local signing code, an agent token, or a REST auth
token.

### Python Backend

- Agora App ID and App Certificate
- explicit Agora Fengming ASR, managed OpenAI `gpt-4o-mini`, and MiniMax
  `speech_2_6_turbo` configuration
- combined user RTC + RTM token generation
- `agora-agents==2.4.1` client and session lifecycle
- agent RTC credential and REST authentication generation inside the SDK
- active `agentId` to `AsyncAgentSession` tracking
- tracked stop plus stateless idempotent fallback

The backend serializes ASR explicitly as `{"vendor":"fengming"}`. OpenAI and
MiniMax constructors do not receive provider keys, and the SDK converts them to
the managed preset
`openai_gpt_4o_mini,minimax_speech_2_6_turbo`. Request-shape tests lock both
forms and verify that third-party credential fields are absent.

## Startup Sequence

```text
Tap Start
  -> request microphone permission
  -> GET /get_config with a new channel and process-stable user UID
  -> validate returned App ID, token, UIDs, and channel
  -> initialize RTC and RTM
  -> create Toolkit, register handler, loadAudioSettings()
  -> RTM login
  -> RTC join and wait for didJoinChannel
  -> subscribeMessage and require successful completion
  -> POST /startAgent with channel, UIDs, SOS mode, and EOS mode
  -> require a non-empty agentId
  -> show connected UI
```

`SessionStartupState` remains intentionally small. Agent start is permitted
only while connecting and after RTC join, RTM login, and Toolkit subscription
are all complete.

Turn detection remains independent:

- SOS maps to `turn_detection.config.start_of_speech.mode`
- EOS maps to `turn_detection.config.end_of_speech.mode`
- both accept `vad`, `semantic`, or `manual`
- the backend sends only each selected `mode`; it does not add `vad_config` or
  `semantic_config`

## Runtime Data Flow

```text
RTC audio + RTM events
  -> AgoraAgentClientToolkit
  -> ViewController callbacks
  -> transcript / latency / state UI
```

Text messages, image URLs, interrupt, and manual SOS/EOS continue to use
`ConversationalAIAPI`. Agent state and transcript data are never fabricated
from the `/startAgent` HTTP response.

## Stop and Failure Cleanup

```text
capture agentId and AgentManager
  -> fire POST /stopAgent
  -> unsubscribe Toolkit immediately
  -> leave RTC
  -> remove Toolkit handler and destroy Toolkit
  -> log out and destroy RTM client
  -> destroy RTC engine
  -> clear session state and return to Start UI
```

Startup failures use the same resource release path. A delayed or failed
backend stop is logged but cannot keep the UI connected.

## Configuration

Backend secrets live only in `server/.env.local`, copied from
`server/.env.example`. The file is ignored by Git.

`scripts/start_backend.sh` starts FastAPI on `0.0.0.0:8001` by default, detects
the Mac LAN IP, health-checks the service, and writes the ignored
`Config/VoiceAgent-Local.xcconfig`:

```text
AGENT_BACKEND_URL = http://<mac-lan-ip>:8001
```

The Debug target permits local HTTP. The Release target does not include the
ATS development exception. Source plist configuration files are excluded from
the target, so legacy local secrets are not copied into the app bundle.

## Constraints

- Use the Mac LAN IP for a physical iPhone; `localhost` points to the phone.
- Keep the Mac and iPhone on the same LAN and allow incoming Python connections.
- Real voice acceptance requires a physical device; Simulator builds are only
  compilation and basic integration evidence.
- Production must replace this local backend with an authenticated deployed
  service and production token policy.
