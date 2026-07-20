#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/voiceagent-swift-tests.XXXXXX")"
trap 'rm -rf "${BUILD_DIR}"' EXIT

swiftc \
  "${ROOT_DIR}/VoiceAgent/SessionStartupState.swift" \
  "${ROOT_DIR}/Tests/SessionStartupStateTests.swift" \
  -o "${BUILD_DIR}/session-startup-tests"
"${BUILD_DIR}/session-startup-tests"

swiftc \
  "${ROOT_DIR}/VoiceAgent/Tools/NetworkManager.swift" \
  "${ROOT_DIR}/VoiceAgent/Tools/AgentManager.swift" \
  "${ROOT_DIR}/Tests/BackendClientTests.swift" \
  -o "${BUILD_DIR}/backend-client-tests"
"${BUILD_DIR}/backend-client-tests"
