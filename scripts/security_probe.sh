#!/usr/bin/env bash
set -euo pipefail

HOST="${SOCKS_HOST:-127.0.0.1}"
PORT="${SOCKS_PORT:-1080}"
USER="${SOCKS_USER:-}"
PASS="${SOCKS_PASS:-}"
TARGET_URL="${TARGET_URL:-https://api.ipify.org}"

echo "Probe 1: unauthenticated SOCKS should fail"
if curl --max-time 5 --socks5 "${HOST}:${PORT}" "${TARGET_URL}" >/dev/null 2>&1; then
  echo "FAIL: unauthenticated SOCKS connection succeeded"
  exit 1
fi
echo "PASS: unauthenticated connection rejected"

if [[ -n "${USER}" && -n "${PASS}" ]]; then
  echo "Probe 2: wrong password should fail"
  if curl --max-time 5 --socks5 "wrong:${PASS}@${HOST}:${PORT}" "${TARGET_URL}" >/dev/null 2>&1; then
    echo "FAIL: wrong password accepted"
    exit 1
  fi
  echo "PASS: wrong password rejected"

  echo "Probe 3: valid credentials should succeed"
  curl --max-time 10 --socks5 "${USER}:${PASS}@${HOST}:${PORT}" "${TARGET_URL}"
  echo
  echo "PASS: authenticated SOCKS works"
fi

echo "Security probe completed"
