#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="${ROOT_DIR}/server"
ENV_FILE="${VOICEAGENT_ENV_FILE:-${SERVER_DIR}/.env.local}"
VENV_DIR="${SERVER_DIR}/.venv"
LOCAL_CONFIG_FILE="${VOICEAGENT_LOCAL_CONFIG_FILE:-${ROOT_DIR}/Config/VoiceAgent-Local.xcconfig}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Create it from server/.env.example and fill in your own credentials."
  exit 1
fi

CONFIGURED_PORT="$(awk -F= '
  /^[[:space:]]*PORT[[:space:]]*=/ {
    value = substr($0, index($0, "=") + 1)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    gsub(/^['\''"]|['\''"]$/, "", value)
    print value
    exit
  }
' "${ENV_FILE}")"
PORT="${PORT:-${CONFIGURED_PORT:-8001}}"
if ! [[ "${PORT}" =~ ^[0-9]+$ ]] || (( ${#PORT} > 5 )); then
  echo "Invalid PORT '${PORT}'. Use an integer from 1 to 65535."
  exit 1
fi
PORT="$((10#${PORT}))"
if (( PORT < 1 || PORT > 65535 )); then
  echo "Invalid PORT '${PORT}'. Use an integer from 1 to 65535."
  exit 1
fi

if ! python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 10))'; then
  echo "Python 3.10 or later is required. Install a newer Python and retry."
  exit 1
fi

if ! python3 -c \
  'import socket, sys; sock = socket.socket(); sock.bind(("0.0.0.0", int(sys.argv[1]))); sock.close()' \
  "${PORT}" 2>/dev/null; then
  echo "Port ${PORT} is already in use. Set PORT to a free port in ${ENV_FILE} or before the command."
  exit 1
fi

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  python3 -m venv "${VENV_DIR}"
fi

if [[ "${VOICEAGENT_SKIP_INSTALL:-0}" != "1" ]]; then
  "${VENV_DIR}/bin/python" -m pip install --disable-pip-version-check -r "${SERVER_DIR}/requirements.txt"
fi

LAN_IP="${VOICEAGENT_LAN_IP:-}"
if [[ -z "${LAN_IP}" ]]; then
  DEFAULT_INTERFACE="$(/sbin/route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}' || true)"
  if [[ -n "${DEFAULT_INTERFACE}" ]]; then
    LAN_IP="$(/usr/sbin/ipconfig getifaddr "${DEFAULT_INTERFACE}" 2>/dev/null || true)"
  fi
  if [[ -z "${LAN_IP}" ]]; then
    for interface in en0 en1; do
      LAN_IP="$(/usr/sbin/ipconfig getifaddr "${interface}" 2>/dev/null || true)"
      if [[ -n "${LAN_IP}" ]]; then
        break
      fi
    done
  fi
fi
if [[ -z "${LAN_IP}" ]]; then
  echo "Unable to detect an active Mac LAN IP. Connect the Mac to Wi-Fi or Ethernet and retry."
  exit 1
fi

cd "${SERVER_DIR}"
"${VENV_DIR}/bin/python" -m uvicorn src.server:app --env-file "${ENV_FILE}" --host 0.0.0.0 --port "${PORT}" &
SERVER_PID=$!

cleanup() {
  kill "${SERVER_PID}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

HEALTH_URL="http://127.0.0.1:${PORT}/health"
for _ in $(seq 1 30); do
  if curl --silent --fail "${HEALTH_URL}" >/dev/null; then
    break
  fi
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "Backend exited before becoming healthy."
    wait "${SERVER_PID}"
    exit 1
  fi
  sleep 1
done

if ! curl --silent --fail "${HEALTH_URL}" >/dev/null; then
  echo "Backend health check timed out at ${HEALTH_URL}."
  exit 1
fi
sleep 1
if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
  echo "Backend exited after the health check. Port ${PORT} may already be in use."
  wait "${SERVER_PID}"
  exit 1
fi

BACKEND_URL="http://${LAN_IP}:${PORT}"
XCCONFIG_URL="http:\$(AGENT_BACKEND_SLASH)\$(AGENT_BACKEND_SLASH)${LAN_IP}:${PORT}"
TEMP_CONFIG="$(mktemp "${TMPDIR:-/tmp}/voiceagent-local.XXXXXX")"
if [[ -f "${LOCAL_CONFIG_FILE}" ]]; then
  awk -v url="${XCCONFIG_URL}" '
    BEGIN { saw_slash = 0; saw_url = 0 }
    /^[[:space:]]*AGENT_BACKEND_SLASH[[:space:]]*=/ {
      print "AGENT_BACKEND_SLASH = /"
      saw_slash = 1
      next
    }
    /^[[:space:]]*AGENT_BACKEND_URL[[:space:]]*=/ {
      print "AGENT_BACKEND_URL = " url
      saw_url = 1
      next
    }
    { print }
    END {
      if (!saw_slash) print "AGENT_BACKEND_SLASH = /"
      if (!saw_url) print "AGENT_BACKEND_URL = " url
    }
  ' "${LOCAL_CONFIG_FILE}" > "${TEMP_CONFIG}"
else
  printf 'AGENT_BACKEND_SLASH = /\nAGENT_BACKEND_URL = %s\n' "${XCCONFIG_URL}" > "${TEMP_CONFIG}"
fi
mv "${TEMP_CONFIG}" "${LOCAL_CONFIG_FILE}"

echo "VoiceAgent backend is ready."
echo "Mac:    http://127.0.0.1:${PORT}"
echo "iPhone: ${BACKEND_URL}"
echo "Keep this terminal open while using the app."

wait "${SERVER_PID}"
