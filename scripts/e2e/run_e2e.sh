#!/usr/bin/env bash
#
# One-command local E2E: start a real ConnectOnion agent, run the real-agent XCUITest
# against it, then tear the agent down.
#
#   scripts/e2e/run_e2e.sh
#
# Prerequisites (see scripts/e2e/README.md):
#   - Xcode 26 with an iOS 26 simulator
#   - python3 with `connectonion` installed        ->  pip install connectonion
#   - a one-time ConnectOnion identity + API key    ->  co auth
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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
[ -x "$XCODEBUILD" ] || die "No full Xcode found at DEVELOPER_DIR=$DEVELOPER_DIR (install Xcode 26, or set DEVELOPER_DIR)."

# ---------------------------------------------------------------- prerequisite checks
info "Checking prerequisites…"
command -v python3 >/dev/null 2>&1 || die "python3 not found."

python3 -c "import connectonion" 2>/dev/null \
  || die "The 'connectonion' package is not installed. Run:  pip install connectonion"

AGENT_ADDR="$(python3 - <<'PY'
from pathlib import Path
try:
    from connectonion import address
    data = address.load(Path.home() / ".co")
    print(data.get("address", "") if data else "")
except Exception:
    print("")
PY
)"
[ -n "$AGENT_ADDR" ] || die "No ConnectOnion identity in ~/.co. Run a one-time:  co auth"
ok "Agent identity: ${AGENT_ADDR:0:10}…${AGENT_ADDR: -4}"

# port must be free
if lsof -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  die "Port $PORT is already in use. Stop that process or set E2E_PORT=<other>."
fi

# ---------------------------------------------------------------- start the agent
info "Starting local agent on $ENDPOINT (log: $AGENT_LOG)…"
E2E_PORT="$PORT" python3 "$SCRIPT_DIR/agent_server.py" >"$AGENT_LOG" 2>&1 &
AGENT_PID=$!

cleanup() {
  if kill -0 "$AGENT_PID" 2>/dev/null; then
    info "Stopping agent (pid $AGENT_PID)…"
    kill "$AGENT_PID" 2>/dev/null || true
    wait "$AGENT_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# wait until the port accepts connections (or the agent dies)
info "Waiting for the agent to be ready…"
for _ in $(seq 1 60); do
  if ! kill -0 "$AGENT_PID" 2>/dev/null; then
    fail "Agent process exited early. Last log lines:"; tail -n 20 "$AGENT_LOG" >&2; exit 1
  fi
  if curl -s -o /dev/null "$ENDPOINT" 2>/dev/null; then ready=1; break; fi
  sleep 0.5
done
[ "${ready:-}" = "1" ] || { fail "Agent did not become ready in 30s. Log:"; tail -n 20 "$AGENT_LOG" >&2; exit 1; }
ok "Agent is up."

# ---------------------------------------------------------------- run the E2E test
info "Running $ONLY_TESTING against the live agent…"
set +e
"$XCODEBUILD" test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=${SIMULATOR},OS=${OS_VERSION}" \
  -only-testing:"$ONLY_TESTING" \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  TEST_RUNNER_E2E_AGENT_ADDRESS="$AGENT_ADDR" \
  TEST_RUNNER_E2E_AGENT_ENDPOINT="$ENDPOINT"
STATUS=$?
set -e

echo
if [ "$STATUS" -eq 0 ]; then
  ok "E2E PASSED — the iOS app talked to a live ConnectOnion agent end-to-end."
else
  fail "E2E FAILED (exit $STATUS). Agent-side log: $AGENT_LOG"
  fail "If the app connected but no answer streamed, check the model/credentials from 'co auth'."
fi
exit "$STATUS"
