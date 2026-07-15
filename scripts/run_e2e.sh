#!/usr/bin/env bash
#
# One-command local E2E: start a real ConnectOnion agent, run the real-agent XCUITest
# against it, then tear the agent down.
#
#   scripts/run_e2e.sh
#
# Prerequisites (see README.md next to this script):
#   - Xcode 26 with an iOS 26 simulator
#   - `connectonion` available to python (pip install connectonion) OR `uv` installed
#   - a one-time ConnectOnion identity + API key in ~/.co  (co auth)
#
# Optional overrides (env vars):
#   E2E_PORT=8000                 agent port
#   E2E_SIMULATOR="iPhone 17"     simulator device name
#   E2E_OS=latest                 simulator OS version
#   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
set -euo pipefail

# ---------------------------------------------------------------- config
PORT="${E2E_PORT:-8000}"
ENDPOINT="http://localhost:${PORT}"
SIMULATOR="${E2E_SIMULATOR:-iPhone 17}"
OS_VERSION="${E2E_OS:-latest}"
SCHEME="ConnectOnion iOS"
ONLY_TESTING="ConnectOnion iOSUITests/ConnectOnion_iOSE2ETests"
CO_DIR="$HOME/.co"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")"
PROJECT="$REPO_ROOT/ConnectOnion iOS.xcodeproj"
AGENT_LOG="$(mktemp -t co-e2e-agent-XXXX).log"

info()  { printf '\033[1;34m▸ %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }
die()   { fail "$*"; exit 1; }

# ---------------------------------------------------------------- pick a full Xcode (not CommandLineTools)
if [ -z "${DEVELOPER_DIR:-}" ]; then
  sel="$(xcode-select -p 2>/dev/null || true)"
  case "$sel" in
    *CommandLineTools*|"") DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" ;;
    *)                     DEVELOPER_DIR="$sel" ;;
  esac
fi
export DEVELOPER_DIR
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"
[ -x "$XCODEBUILD" ] || die "No full Xcode at DEVELOPER_DIR=$DEVELOPER_DIR (install Xcode 26, or set DEVELOPER_DIR)."

# ---------------------------------------------------------------- find connectonion WITH host()
# NOTE: host() is the agent-server API. The PyPI `connectonion` is behind (0.4.x, no host()); the
# team's backend checkout (repo/connectonion, v1.2+) has it. So prefer a local checkout.
info "Locating connectonion (with host())…"
PYRUN=()
for py in python3 python; do
  if command -v "$py" >/dev/null 2>&1 && "$py" -c "from connectonion import host" >/dev/null 2>&1; then
    PYRUN=("$py"); ok "Using system python: ${py}"; break
  fi
done
if [ ${#PYRUN[@]} -eq 0 ]; then
  # resolve the connectonion backend source: explicit override → sibling checkout → PyPI (may lack host())
  CO_SRC="${E2E_CONNECTONION_PATH:-}"
  if [ -z "$CO_SRC" ] && [ -d "$REPO_ROOT/../connectonion" ]; then
    CO_SRC="$(cd "$REPO_ROOT/../connectonion" && pwd)"
  fi
  [ -n "$CO_SRC" ] || CO_SRC="connectonion"
  command -v uv >/dev/null 2>&1 \
    || die "connectonion with host() not importable and 'uv' is not installed. Install the connectonion backend, or set E2E_CONNECTONION_PATH."
  PYRUN=(uv run --quiet --python 3.12 --with "$CO_SRC" python)
  ok "Using: uv run --with ${CO_SRC}"
fi

# ---------------------------------------------------------------- resolve the agent address + credentials
[ -d "$CO_DIR" ] || die "No ConnectOnion identity at ~/.co. Run a one-time:  co auth"

# credentials (OPENONION_API_KEY etc.) live in ~/.co/keys.env — export them for the agent's LLM calls
if [ -f "$CO_DIR/keys.env" ]; then
  set -a; # shellcheck disable=SC1091
  . "$CO_DIR/keys.env"; set +a
fi

AGENT_ADDR="${AGENT_ADDRESS:-}"
if [ -z "$AGENT_ADDR" ]; then
  AGENT_ADDR="$("${PYRUN[@]}" - <<'PY' 2>/dev/null || true
from pathlib import Path
try:
    from connectonion import address
    d = address.load(Path.home() / ".co")
    print(d.get("address", "") if d else "")
except Exception:
    print("")
PY
)"
fi
[ -n "$AGENT_ADDR" ] || die "Could not resolve the agent address (no AGENT_ADDRESS in ~/.co/keys.env). Run:  co auth"
ok "Agent identity: ${AGENT_ADDR:0:10}…${AGENT_ADDR: -4}"

# port must be free
if lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  die "Port $PORT is already in use. Stop that process or set E2E_PORT=<other>."
fi

# ---------------------------------------------------------------- start the agent
info "Starting local agent on $ENDPOINT (log: $AGENT_LOG)…"
E2E_PORT="$PORT" "${PYRUN[@]}" "$SCRIPT_DIR/agent_server.py" >"$AGENT_LOG" 2>&1 &
AGENT_PID=$!

cleanup() {
  if kill -0 "$AGENT_PID" 2>/dev/null; then
    info "Stopping agent (pid $AGENT_PID)…"
    kill "$AGENT_PID" 2>/dev/null || true
    wait "$AGENT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

info "Waiting for the agent to be ready…"
ready=""
for _ in $(seq 1 120); do
  if ! kill -0 "$AGENT_PID" 2>/dev/null; then
    fail "Agent process exited early. Last log lines:"; tail -n 25 "$AGENT_LOG" >&2; exit 1
  fi
  if curl -s -o /dev/null "$ENDPOINT" 2>/dev/null; then ready=1; break; fi
  sleep 0.5
done
[ "$ready" = "1" ] || { fail "Agent did not become ready in 60s. Log:"; tail -n 25 "$AGENT_LOG" >&2; exit 1; }
ok "Agent is up."

# ---------------------------------------------------------------- run the E2E test
# The address reaches the test via XCTest's TEST_RUNNER_ prefix mechanism, which forwards
# environment variables (prefix stripped) to the runner. They must be ENV VARS for xcodebuild,
# NOT build-setting arguments — otherwise the test can't read E2E_AGENT_ADDRESS and skips.
info "Running $ONLY_TESTING against the live agent…"
# NB: do NOT disable code signing here. The real (non-mock) app creates its Ed25519 identity in the
# Keychain to sign CONNECT; CODE_SIGNING_ALLOWED=NO strips the keychain entitlement so the identity
# fails with errSecMissingEntitlement (-34018) and CONNECT is never sent (app shows "Disconnected").
# Simulator builds sign ad-hoc and DO apply entitlements, so the default signing works.
XCB_LOG="$(mktemp -t co-e2e-xcb-XXXX).log"
set +e
TEST_RUNNER_E2E_AGENT_ADDRESS="$AGENT_ADDR" \
TEST_RUNNER_E2E_AGENT_ENDPOINT="$ENDPOINT" \
"$XCODEBUILD" test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=${OS_VERSION}" \
  -only-testing:"$ONLY_TESTING" \
  -parallel-testing-enabled NO 2>&1 | tee "$XCB_LOG"
STATUS=${PIPESTATUS[0]}
set -e

echo
if grep -q "test skipped" "$XCB_LOG"; then
  fail "E2E was SKIPPED — the agent address didn't reach the test runner. Check TEST_RUNNER_ env passing."
  exit 3
elif [ "$STATUS" -eq 0 ]; then
  ok "E2E PASSED — the iOS app talked to a live ConnectOnion agent end-to-end."
else
  fail "E2E FAILED (exit $STATUS). Agent-side log: $AGENT_LOG"
  fail "If the app connected but no answer streamed, check the model/credentials from 'co auth'."
fi
exit "$STATUS"
