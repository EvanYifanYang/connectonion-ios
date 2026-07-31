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
| 2 | `connectonion>=1.5.3` from PyPI (must expose `host()`) | `pip install -U connectonion` |
| 3 | A ConnectOnion identity + API key | `co auth` (creates `~/.co`, provisions the Gemini free-tier key) |

**Note on step 2 — Python runtime.** Current PyPI releases expose `host()`. The script resolves the
runtime in this order:

1. `$E2E_PYTHON` (an explicit interpreter or virtualenv directory), else
2. `$E2E_CONNECTONION_PATH` (an explicit source-development override), else
3. an explicit `$E2E_CONNECTONION_SPEC`, forced into an isolated `uv run` environment, else
4. a system Python where `from connectonion import host` already works, else
5. PyPI `connectonion>=1.5.3`, installed into an isolated `uv run` environment.

The launcher never auto-selects a sibling checkout, so the default E2E path cannot silently test
local source instead of the package users actually install. If a prerequisite is missing, the script
stops early and says which.

To use an existing virtualenv:

```bash
E2E_PYTHON=/path/to/.venv/bin/python ./scripts/run_e2e.sh
# Passing the virtualenv directory itself is also supported:
E2E_PYTHON=/path/to/.venv ./scripts/run_e2e.sh
```

## Options (env vars)

| Var | Default | Purpose |
|---|---|---|
| `E2E_SIMULATOR` | `iPhone 17` | Simulator device name |
| `E2E_OS` | `latest` | Simulator iOS version |
| `E2E_PORT` | `8000` | Local agent port |
| `E2E_PYTHON` | auto-detected | Explicit Python executable or virtualenv directory |
| `E2E_CONNECTONION_SPEC` | unset (fallback: `connectonion>=1.5.3`) | Explicit PyPI requirement passed to `uv`; when set, it overrides system Python |
| `E2E_CONNECTONION_PATH` | unset | Explicit local-source override for framework development only |
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
| `'connectonion' package is not installed` | `pip install -U connectonion`, set `E2E_PYTHON`, or install `uv` for the isolated PyPI fallback |
| `No ConnectOnion identity in ~/.co` | `co auth` |
| `Port 8000 is already in use` | stop the other process, or `E2E_PORT=8010 ./scripts/run_e2e.sh` |
| App **Disconnected** + `Keychain operation failed (-34018)` banner (agent log: `ws+` then `ws-`, no `CONNECT`) | keychain entitlement missing — **don't disable code signing** (the script leaves signing at its default so the simulator applies entitlements). |
| App **Disconnected**, no keychain error, agent logs `ws+`/`ws-` with no `CONNECT` | possible iOS-client ↔ package **protocol/version mismatch** — select the intended venv with `E2E_PYTHON` or pin PyPI with `E2E_CONNECTONION_SPEC=connectonion==1.5.3`. |
| App connected, `CONNECT`/`INPUT` logged, but no `42` | the agent's LLM call failed — check the balance / re-run `co auth` (free tier is Gemini-only) |
| `No full Xcode found` | install Xcode 26, or `sudo xcode-select -s /Applications/Xcode.app` |

## Files

| File | What |
|---|---|
| `run_e2e.sh` | the one-command launcher |
| `agent_server.py` | the local test agent (one `add` tool, `co/gemini-2.5-flash`) |
