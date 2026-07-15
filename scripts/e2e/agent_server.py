"""Local E2E smoke-test agent for the ConnectOnion iOS client (COMP9900 Mon18).

Hosts a minimal ConnectOnion agent (one `add` tool) on http://localhost:$E2E_PORT so the
XCUITest `ConnectOnion iOSUITests/ConnectOnion_iOSE2ETests` can drive the *real* app against
a *real* agent (real WebSocket + Ed25519 handshake + real LLM + real tool call).

Run it via `run_e2e.sh`, which starts this server, injects the agent address into the test,
runs the test, and tears the server down. You normally don't run this file by hand.

Requires: `pip install connectonion` and a one-time `co auth` (creates the ~/.co identity and
the managed OpenOnion API key used by the `co/…` model).
"""
import os
from pathlib import Path

from connectonion import Agent, host, address

CO_DIR = Path.home() / ".co"
PORT = int(os.environ.get("E2E_PORT", "8000"))


def add(a: int, b: int) -> int:
    """Add two integers and return the sum."""
    return a + b


def create_agent() -> Agent:
    return Agent(
        name="assistant",
        system_prompt="You are a helpful assistant for an iOS E2E test. Keep replies to one short sentence.",
        tools=[add],
        model="co/gemini-2.5-flash",  # free OpenOnion tier only covers Gemini models
    )


# Print the agent's address in a parseable form for the launcher's log (run_e2e.sh reads the
# address directly from ~/.co, so this line is informational).
_identity = address.load(CO_DIR)
if _identity and _identity.get("address"):
    print(f"E2E_AGENT_ADDRESS={_identity['address']}", flush=True)
else:
    print("E2E_AGENT_ADDRESS=MISSING (run `co auth` first)", flush=True)

# host() blocks (runs uvicorn). Local only: no relay, open trust, reuse the ~/.co identity.
host(create_agent, port=PORT, trust="open", relay_url=None, co_dir=CO_DIR)
