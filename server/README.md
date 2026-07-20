# VoiceAgent Local Backend

This FastAPI service owns the Agora App Certificate, user token generation, and
Conversational AI agent lifecycle for the iOS demo. It explicitly uses Agora
Fengming STT with managed OpenAI LLM and MiniMax TTS, so no third-party provider
keys are required. It is a local development service, not a production
deployment template. Python 3.10 or later is required.

## Configuration

```bash
cp server/.env.example server/.env.local
```

Set `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` in `server/.env.local`.
`AGENT_PROMPT` and `AGENT_GREETING` are optional copy settings. The backend pins
`agora-agents==2.4.1`. `PORT` is optional and defaults to `8001`.

## Start

From the repository root, run:

```bash
./scripts/start_backend.sh
```

The script creates `server/.venv`, installs the pinned requirements, starts the
service on `0.0.0.0:8001` by default, detects the Mac LAN IP, and configures the
ignored iOS `Config/VoiceAgent-Local.xcconfig`. The iPhone and Mac must use the
same LAN.

Allow incoming Python connections if macOS asks. Do not use `localhost` on a
physical iPhone because it points back to the phone.

Successful `/get_config` responses use `Cache-Control: no-store`. The backend
sets the Agora SDK request timeout to 25 seconds, below the iOS client's
30-second timeout.

## Test

```bash
server/.venv/bin/python -m pytest server/tests -q
```
