"""A "kitchen-sink" ConnectOnion agent to exercise every ConnectOnion iOS client surface.

Run from the sibling connectonion repo (its venv is the one that exports host()):
    cd repo/connectonion
    uv run python ../capstone-project-26t2-9900-t11c-almond/scripts/super_agent.py
Reachable by its 0x address over the relay (host()'s default wss://oo.openonion.ai).

Covers, best-effort (each optional capability is wrapped so a missing piece never
stops the agent from booting — it just prints what loaded and what needs setup):
  • many plain tools            → tool-call group card
  • ask_user (options + fields) → Ask User card
  • propose_plan                → Plan Review card
  • generate_image             → agent image card (needs image_result_formatter)
  • shell/bash (approval-gated) → Approval card (shell_approval plugin)
  • browser automation          → screenshots surface as images
  • gmail / calendar            → real tools (need OAuth to actually work)
  • re_act plugin               → thinking / intent rows
"""
import ast
import base64
import datetime
import operator
import random
import struct
import zlib
from pathlib import Path

from connectonion import Agent, host

CO_DIR = Path.home() / ".co"
loaded: list[str] = []
skipped: list[str] = []


# ─────────────────────────── plain demo tools ───────────────────────────
# Names are prefixed to avoid colliding with class-tool methods (e.g. TodoList.add).
def add_numbers(a: int, b: int) -> int:
    """Add two integers."""
    return a + b


def subtract_numbers(a: int, b: int) -> int:
    """Subtract b from a."""
    return a - b


def multiply_numbers(a: int, b: int) -> int:
    """Multiply two integers."""
    return a * b


_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
        ast.Div: operator.truediv, ast.Pow: operator.pow, ast.Mod: operator.mod,
        ast.USub: operator.neg, ast.UAdd: operator.pos}


def _eval(node):
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, ast.BinOp):
        return _OPS[type(node.op)](_eval(node.left), _eval(node.right))
    if isinstance(node, ast.UnaryOp):
        return _OPS[type(node.op)](_eval(node.operand))
    raise ValueError("unsupported")


def calculate(expression: str) -> str:
    """Evaluate a basic arithmetic expression, e.g. "3 * (4 + 5) ** 2"."""
    try:
        return str(_eval(ast.parse(expression, mode="eval").body))
    except Exception as exc:  # noqa: BLE001
        return f"Could not evaluate: {exc}"


def get_weather(city: str) -> str:
    """Get today's weather for a city (demo data)."""
    cond = ["Sunny", "Cloudy", "Rainy", "Windy", "Clear", "Foggy"][abs(hash(city.lower())) % 6]
    return f"{city.title()}: {cond}, {12 + abs(hash(city.lower())) % 18}°C"


def current_time() -> str:
    """Return the current local date and time."""
    return datetime.datetime.now().strftime("%A %Y-%m-%d %H:%M:%S")


def random_number(low: int, high: int) -> int:
    """Return a random integer between low and high inclusive."""
    return random.randint(low, high)


def roll_dice(sides: int = 6, count: int = 1) -> str:
    """Roll `count` dice of `sides` sides; returns the rolls and total."""
    rolls = [random.randint(1, max(2, sides)) for _ in range(max(1, count))]
    return f"Rolled {rolls} — total {sum(rolls)}"


def flip_coin() -> str:
    """Flip a fair coin."""
    return random.choice(["Heads", "Tails"])


def word_count(text: str) -> int:
    """Count the words in a piece of text."""
    return len(text.split())


def reverse_text(text: str) -> str:
    """Reverse a string."""
    return text[::-1]


def is_prime(n: int) -> bool:
    """Return whether n is a prime number."""
    if n < 2:
        return False
    return all(n % i for i in range(2, int(n ** 0.5) + 1))


def fibonacci(n: int) -> int:
    """Return the nth Fibonacci number (0-indexed)."""
    a, b = 0, 1
    for _ in range(max(0, n)):
        a, b = b, a + b
    return a


def celsius_to_fahrenheit(c: float) -> float:
    """Convert Celsius to Fahrenheit."""
    return round(c * 9 / 5 + 32, 2)


# ─────────────────── interactive / rich-event tools ───────────────────
def _png(w: int, h: int, rgb) -> bytes:
    r, g, b = rgb
    raw = b"".join(b"\x00" + bytes([r, g, b]) * w for _ in range(h))

    def chunk(typ, data):
        c = typ + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw))
            + chunk(b"IEND", b""))


def generate_image(color: str = "purple") -> str:
    """Generate a small solid-color image and return it as a data URL (tests the image card)."""
    palette = {"purple": (139, 120, 214), "green": (60, 200, 90), "red": (220, 70, 70),
               "blue": (80, 120, 246), "black": (20, 20, 22)}
    png = _png(120, 120, palette.get(color.lower(), (139, 120, 214)))
    return "data:image/png;base64," + base64.b64encode(png).decode()


def propose_plan(agent, plan: str) -> str:
    """Present a step-by-step plan for the user to review/approve before you act.

    Args:
        plan: The plan as markdown text (a few numbered steps).
    """
    io = getattr(agent, "io", None)
    if io is None:
        return "No interactive channel available; proceeding without review."
    try:
        io.send({"type": "plan_review", "plan_content": plan})
        resp = io.receive()
        msg = resp.get("message", "") if isinstance(resp, dict) else str(resp)
        return f"User responded to the plan: {msg or '(approved)'}"
    except Exception as exc:  # noqa: BLE001
        return f"Plan review channel unavailable: {exc}"


SAFE_TOOLS = [
    add_numbers, subtract_numbers, multiply_numbers, calculate, get_weather,
    current_time, random_number, roll_dice, flip_coin, word_count, reverse_text,
    is_prime, fibonacci, celsius_to_fahrenheit,
    generate_image, propose_plan,
]


def _probe_ok(tools) -> bool:
    """Return True if this tool list builds without a duplicate/other tool error.

    Class tools expand their public methods into tools, so two class tools (or a
    class method vs one of our functions) can collide by name — we vet each addition
    against a throwaway Agent so one bad tool skips itself instead of crashing boot.
    """
    try:
        Agent(name="probe", system_prompt="probe", tools=tools, model="co/gemini-2.5-flash")
        return True
    except Exception as exc:  # noqa: BLE001
        _probe_ok.last_error = exc  # type: ignore[attr-defined]
        return False


def build_tools():
    from connectonion import useful_tools as ut

    def browser_automation():
        mod = __import__("connectonion.useful_tools.browser_tools",
                         fromlist=["BrowserAutomation"])
        return mod.BrowserAutomation()

    candidates = [
        ("ask_user", lambda: ut.ask_user),
        ("read_file", lambda: ut.read_file),
        ("web_fetch (WebFetch)", lambda: ut.WebFetch()),
        ("memory (Memory)", lambda: ut.Memory(memory_dir=str(CO_DIR / "super_agent_memory"))),
        ("todo_list (TodoList)", lambda: ut.TodoList()),
        ("bash", lambda: ut.bash),                      # ⚠️ approval-gated (shell_approval)
        ("shell (Shell)", lambda: ut.Shell()),          # ⚠️ approval-gated (shell_approval)
        ("browser (BrowserAutomation)", browser_automation),  # needs a browser installed
        ("google_calendar (GoogleCalendar)", lambda: ut.GoogleCalendar()),  # needs OAuth
        ("gmail (Gmail)", lambda: ut.Gmail()),          # needs data csv / OAuth
    ]

    tools = list(SAFE_TOOLS)
    for label, factory in candidates:
        try:
            inst = factory()
        except Exception as exc:  # noqa: BLE001
            skipped.append(f"{label} — init failed ({exc})")
            continue
        if _probe_ok(tools + [inst]):
            tools.append(inst)
            loaded.append(label)
        else:
            skipped.append(f"{label} — name clash ({getattr(_probe_ok, 'last_error', '?')})")
    return tools


def build_plugins():
    plugins = []
    from connectonion import useful_plugins as up

    for label in ("re_act", "image_result_formatter", "shell_approval"):
        try:
            plugins.append(getattr(up, label))
            loaded.append(f"plugin:{label}")
        except Exception as exc:  # noqa: BLE001
            skipped.append(f"plugin:{label} ({exc})")
    return plugins


SYSTEM_PROMPT = (
    "You are Kitchen Sink, a demo agent that shows off every capability. You have many tools "
    "(math, calculator, weather, time, randomness, dice, text, primes, Fibonacci, temperature). "
    "You can also: ask the user a question with options or form fields (ask_user); present a plan "
    "for review before acting (propose_plan) — use this when the user asks you to plan or do "
    "something multi-step; generate an image (generate_image); fetch web pages; remember notes; "
    "keep a todo list; run shell commands (these need the user's approval); and browse the web. "
    "Use whatever tool fits. When the user asks to 'test the plan flow', call propose_plan. When "
    "they ask to 'test approval', run a shell command that WRITES something (not a read-only one), "
    "e.g. 'mkdir /tmp/co_approval_demo' — a non-safe command so the approval gate actually fires. "
    "Keep chat replies short and friendly."
)


def create_agent() -> Agent:
    tools = build_tools()
    plugins = build_plugins()
    try:
        return Agent(name="Kitchen Sink", system_prompt=SYSTEM_PROMPT, tools=tools,
                     plugins=plugins, model="co/gemini-2.5-flash")
    except Exception as exc:  # noqa: BLE001
        print(f"[super_agent] Agent(plugins=…) failed ({exc}); retrying without plugins", flush=True)
        return Agent(name="Kitchen Sink", system_prompt=SYSTEM_PROMPT, tools=tools,
                     model="co/gemini-2.5-flash")


if __name__ == "__main__":
    # Build once up front just to print a load report (host() will build again).
    create_agent()
    print("\n================ SUPER AGENT capability report ================", flush=True)
    print("LOADED  :", ", ".join(loaded), flush=True)
    print("SKIPPED :", ", ".join(skipped) or "(none)", flush=True)
    print("===============================================================\n", flush=True)
    loaded.clear()
    skipped.clear()
    host(create_agent, port=8000, trust="open", co_dir=CO_DIR)
