# Conversational AI Quickstart - iOS Swift

## Overview

This sample shows how to integrate Agora Conversational AI into an iOS app for real-time voice conversations with an AI agent.

It covers:

- Real-time voice interaction through Agora RTC SDK
- Messaging and state synchronization through Agora RTM SDK
- Live transcript rendering for user and agent messages
- Connection, agent, mute, and transcript state management
- Automatic flow for channel join, RTM login, agent startup, and view switching

## Use Cases

- AI-powered customer support
- Voice assistant applications
- Real-time voice transcription
- Voice-interactive games
- Voice-based education and training

## Requirements

- iOS 13.0 or later
- Xcode 14.0 or later
- CocoaPods 1.11.0 or later
- Agora developer account: [Console](https://console.agora.cn/)
- Real-time Messaging (RTM) enabled in the Agora Console
- Agora App ID and App Certificate

## Quick Start

1. Clone the project:

```bash
git clone https://github.com/AgoraIO-Community/conversational-ai-quickstart-native.git
cd conversational-ai-quickstart-native/ios-swift
```

2. Install CocoaPods dependencies:

```bash
pod install
```

3. Configure the iOS project:

- Open `VoiceAgent.xcworkspace` in Xcode, not `VoiceAgent.xcodeproj`.
- Copy the sample secrets file and fill in your Agora credentials:

```bash
cp VoiceAgent/Secrets.example.plist VoiceAgent/Secrets.plist
```

`VoiceAgent/Secrets.plist` is ignored by Git and must not be committed.
For CI or internal builds, inject `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` as Xcode build settings; `VoiceAgent/Info.plist` maps those settings into the app bundle and `KeyCenter` reads them at runtime.

Configuration fields:

- `AGORA_APP_ID`: Your Agora App ID. Required.
- `AGORA_APP_CERTIFICATE`: Your Agora App Certificate. Required for token generation and REST API authorization.

The default pipeline uses Agora-managed keyless mode. ASR, LLM, and TTS keys and model selection are managed by Agora and billed to your project, so no third-party keys are required in the client.

The managed models are selected by the top-level `preset` field in `ViewController.startAgent()`. The current defaults are:

- ASR: `deepgram_nova_3`
- LLM: `openai_gpt_4o_mini`
- TTS: `minimax_speech_2_6_turbo`; the `voice_id` is supplied in code, while the preset supplies the key and model.

Before trying the demo, create an Agora project, enable Conversational AI Engine, and get your App ID and App Certificate. See [Enable the service](https://doc.agora.cn/doc/convoai/restful/get-started/enable-service).

4. Run the app:

- Click `Start` to start the voice agent session.

## Notes

- This demo is intended for quick evaluation and development testing only.
- Production apps should not call Agora RESTful APIs directly from the client.
- `AGORA_APP_CERTIFICATE` is bundled in local debug builds and sent to the demo token service in this sample, which is not safe for production.
- In production, the client should call your own backend. Your backend should generate tokens and call Agora RESTful APIs.

## Resources

- [Agora RTC iOS SDK documentation](https://doc.agora.cn/doc/rtc/ios/landing-page)
- [Agora RTM iOS SDK documentation](https://doc.agora.cn/doc/rtm2/ios/landing-page)
- [Conversational AI RESTful API documentation](https://doc.agora.cn/doc/convoai/restful/landing-page)
- [Conversational AI iOS client component documentation](https://doc.agora.cn/api-ref/convoai/ios/ios-component/overview)
- [Agora Developer Community](https://github.com/AgoraIO-Community)
- [Contact Agora Support](https://ticket.agora.cn/)
