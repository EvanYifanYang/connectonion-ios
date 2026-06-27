"""Sprint 1 live-demo ConnectOnion agent.

Run from a disposable demo folder after installing ConnectOnion:

    python demo_agent.py

Then copy the printed agent address and endpoint into the iOS app.
"""

from __future__ import annotations

import os

from connectonion import Agent, host


def sprint_status(topic: str) -> str:
    """Return a short Sprint 1 status summary for the requested topic."""
    return (
        f"Sprint 1 status for {topic}: the demo focuses on saved agent "
        "configuration, Keychain-backed identity, WebSocket connection, "
        "and one request-response chat flow."
    )


def connection_echo(message: str) -> str:
    """Echo the user's message as proof that the remote agent received it."""
    return f"Remote ConnectOnion agent received: {message}"


def create_agent() -> Agent:
    return Agent(
        name="ios_sprint1_demo",
        model=os.getenv("CONNECTONION_MODEL", "gpt-5-mini"),
        system_prompt=(
            "You are the Sprint 1 demo agent for the ConnectOnion native iOS "
            "client. Keep answers concise. When useful, call the tools to prove "
            "that the hosted agent received the iOS client's prompt."
        ),
        tools=[sprint_status, connection_echo],
        max_iterations=5,
        trust="careful",
    )


if __name__ == "__main__":
    host(create_agent, port=int(os.getenv("PORT", "8000")))
