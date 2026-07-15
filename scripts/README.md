# Local E2E smoke test

Runs the **real-agent** end-to-end test (`ConnectOnion iOSUITests/ConnectOnion_iOSE2ETests`)
with one command: it starts a live ConnectOnion agent, drives the real app against it (real
WebSocket + Ed25519 handshake + real LLM + real `add` tool call), then tears the agent down.

> This is the only test that exercises the **real protocol**. Everything else uses mocks.
> It **skips** in CI (no live agent there) — it's meant to be run locally / before a demo.

## Quick start

```bash
./scripts/run_e2e.sh
```

Expected finish: `✓ E2E PASSED — the iOS app talked to a live ConnectOnion agent end-to-end.`

## Prerequisites (one-time)

| # | Requirement | How |
|---|---|---|
| 1 | Xcode 26 + an iOS 26 simulator | Xcode → Settings → Components |
| 2 | The **connectonion backend** (must expose `host()`) | see note ↓ |
| 3 | A ConnectOnion identity + API key | `co auth` (creates `~/.co`, provisions the Gemini free-tier key) |

**Note on step 2 — connectonion source.** The agent uses `host()`, which the **PyPI**
`connectonion` (0.4.x) does **not** export yet. The script resolves a source that does, in order:

1. a Python where `from connectonion import host` already works, else
2. `$E2E_CONNECTONION_PATH` (a checkout you point at), else
3. the sibling backend checkout `../connectonion` (the team's repo layout), else
4. PyPI `connectonion` (fallback — currently lacks `host()`),

running it via `uv` when needed. So on the team layout (`repo/connectonion` next to this repo)
it works with no extra install. If a prerequisite is missing the script stops early and says which.

## Options (env vars)

| Var | Default | Purpose |
|---|---|---|
| `E2E_SIMULATOR` | `iPhone 17` | Simulator device name |
| `E2E_OS` | `latest` | Simulator iOS version |
| `E2E_PORT` | `8000` | Local agent port |
| `DEVELOPER_DIR` | auto-detected | Xcode toolchain (falls back to `/Applications/Xcode.app`) |

```bash
E2E_SIMULATOR="iPhone 16" E2E_OS=26.0 ./scripts/run_e2e.sh
```

## What it does

1. Checks prerequisites (Xcode, `connectonion`, a `~/.co` identity, a free port).
2. Reads the agent's `0x…` address from `~/.co`.
3. Starts `agent_server.py` (an agent with one `add` tool) on `localhost:$E2E_PORT`.
4. Runs the E2E test, injecting the address via `TEST_RUNNER_E2E_AGENT_ADDRESS`.
5. Stops the agent on exit (pass or fail).

## Troubleshooting

| Symptom | Fix |
|---|---|
| `'connectonion' package is not installed` | `pip install connectonion` |
| `No ConnectOnion identity in ~/.co` | `co auth` |
| `Port 8000 is already in use` | stop the other process, or `E2E_PORT=8010 ./scripts/run_e2e.sh` |
| App shows **Disconnected** right after Send (agent log shows `ws+` then `ws-`, no `CONNECT`) | WS handshake didn't complete — usually an iOS-client ↔ backend **protocol/version mismatch**. Point `E2E_CONNECTONION_PATH` at the connectonion version the client targets. |
| App connected, `CONNECT`/`INPUT` logged, but no `42` | the agent's LLM call failed — check the balance / re-run `co auth` (free tier is Gemini-only) |
| `No full Xcode found` | install Xcode 26, or `sudo xcode-select -s /Applications/Xcode.app` |

## Files

| File | What |
|---|---|
| `run_e2e.sh` | the one-command launcher |
| `agent_server.py` | the local test agent (one `add` tool, `co/gemini-2.5-flash`) |
