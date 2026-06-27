# ConnectOnion iOS Sprint 1 Progressive Demo Runbook

本文件配合 `ConnectOnion_iOS_Sprint_1_Progressive_Demo.pptx` 使用。前半部分 speaker notes 与 PPTX 内每页 notes 保持一致；后半部分是 live demo 的讲稿、流程和操作说明。

## Timing

- Total: 10-12 minutes.
- Slides: about 3-4 minutes.
- Live demo: about 8 minutes.
- Scope boundary: only demo Sprint 1 connection slice. Do not spend time on later mobile features.

## Slide Speaker Notes

### Slide 1 - ConnectOnion iOS Sprint 1 Demo

Good morning everyone. We are team ALMOND, and our project is ConnectOnion iOS: a native iPhone client for connecting to remote ConnectOnion AI agents. Today we will keep the scope aligned with Sprint 1. The goal is not to show every feature we have already built, but to prove the foundation slice: save an agent connection securely, connect to a hosted agent, send one message, and receive a response.

### Slide 2 - Sprint 1 Demo Structure

The course asks for a 10 to 12 minute progressive demo. We will use the slides only to set up the problem and design. The live demo will take the majority of the time. We will demonstrate one feature at a time: first the backend agent setup, then the iOS connection setup, then the chat message. That keeps the demo easy to follow and avoids jumping between unrelated mobile features.

### Slide 3 - Problem and Sprint 1 Solution

The problem is mobile access to AI agents. A browser client works, but it does not give us native iOS navigation, persistence, Keychain storage, keyboard behavior, and mobile-first status feedback. Our Sprint 1 solution is intentionally narrow: create the app foundation and make one real connection flow work end to end. If we can save an agent, connect to it, send a prompt, and get a response, then the later sprint features have a stable base.

### Slide 4 - Sprint 1 Checkpoint

In the proposal, Sprint 1 contained five high-priority stories worth 19 points. For this demo checkpoint, we focus only on the visible connection slice: the SwiftUI app shell, saving an agent connection, Keychain-backed identity, connection status, and a message-response loop. The current codebase has more than this, but for Progressive Demo A we are drawing a clear boundary. We will show the Sprint 1 foundation and avoid turning this into a Sprint 2 or Sprint 3 feature tour.

### Slide 5 - Updated Sprint 1 Architecture

This is the updated Sprint 1 architecture. The UI is SwiftUI, but the UI does not talk directly to the network or storage. ViewModels validate input, track session state, and coordinate operations. SwiftData stores non-sensitive app data such as agent profiles and conversation records. Keychain stores the private client identity used to sign connection messages. The ConnectOnionClient resolves the best route, opens a WebSocket, sends a signed CONNECT message, then sends INPUT messages and receives OUTPUT or stream events. This separation is the main reason the app can grow without putting networking code inside views.

### Slide 6 - Design Decisions from Sprint 1

The first decision is persistence. We use SwiftData for structured records because agent profiles and conversation history are not just a few settings. The second decision is security. We do not store private identity material in UserDefaults; it belongs in Keychain. The third decision is protocol shape. WebSocket fits a chat-style agent because it can carry connection status, PING and PONG, stream events, and final output. Finally, we do not add a custom backend for Sprint 1. ConnectOnion already provides hosting, direct endpoints, and relay routing, so the iOS app should stay a native client rather than becoming another server project.

### Slide 7 - Live Demo Focus: One Connection Flow

Now we will move into the live demo. The demo is one story, not a feature grab bag. First we will use the ConnectOnion backend commands to create and customize an agent. Then we will host it so it becomes reachable over HTTP, WebSocket, and relay. After that, we switch to iOS: add the address and endpoint, save it, start a chat, and send a prompt. While the prompt runs, we will point out the connection status and explain that the app is using the signed WebSocket path we just described.

## Live Demo Goal

Audience should understand one thing clearly: a native iOS client can connect to a hosted ConnectOnion agent through a secure, persisted, WebSocket-based flow.

Do not demo attachments, approvals, onboarding, plan review, or other advanced mobile features unless asked in Q&A. Mention that those are intentionally left for later sprint demos.

## Backend Demo Flow

Use a disposable folder so the demo does not modify the main backend clone.

```bash
mkdir -p ~/Desktop/Sprint1Demo
cd ~/Desktop/Sprint1Demo
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip

# README command, production style:
pip install connectonion

# Local-clone option for the actual live demo:
python -m pip install -e /Users/romanticd/Desktop/connectonion
```

Show the main README path:

```bash
co create sprint1-agent
cd sprint1-agent
python agent.py
```

Then show custom initialization. Either paste the relevant code from `Sprint_1/demo_agent.py`, or run that file directly:

```bash
cp "/Users/romanticd/Desktop/ConnectOnion iOS/Sprint_1/demo_agent.py" .
python demo_agent.py
```

Talk track while backend starts:

> The README starts from `pip install connectonion`, then `co create my-agent`, then `python agent.py`. For our demo we customize the agent initialization: we set a name, system prompt, tools, `max_iterations`, and `trust`. The important final step is `host(create_agent)`, equivalent to the README's `host(agent)` idea: it exposes the agent through HTTP, WebSocket, and relay.

Copy from terminal output:

- Agent address: `0x...`
- Simulator endpoint: usually `http://127.0.0.1:8000` or `http://localhost:8000`
- Physical iPhone endpoint: `http://<Mac-LAN-IP>:8000`

Optional backend fallback:

```bash
curl -X POST http://localhost:8000/input \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Use sprint_status to summarize the Sprint 1 iOS connection demo."}'
```

## README Command Coverage

| README item | Demo handling |
| --- | --- |
| `pip install connectonion` | Show as the standard install path; use local editable install if demoing from the cloned repo. |
| `co create my-agent` | Execute in the disposable demo folder. |
| `cd my-agent` + `python agent.py` | Execute once to show the generated project runs. |
| Manual `Agent(...)` usage | Show through `demo_agent.py`: name, model, tools, system prompt, max iterations, trust. |
| `agent.input(...)` | Explain as the local equivalent of what the iOS app triggers remotely through WebSocket. |
| `agent.history.summary()` | Mention as local debugging/history support; not central to the connection demo. |
| `@xray` / `agent.auto_debug()` | Mention as backend debugging capability; skip live execution unless there is spare time. |
| `co init --template playwright` | Mention as template support; do not run in the main demo path. |
| `co ai` | Mention as built-in ConnectOnion coding assistant; avoid launching an interactive side path. |
| `co copy Gmail` | Mention as tool customization pattern; not part of Sprint 1 connection scope. |
| `host(agent)` / `host(create_agent)` | Execute. This is the bridge from backend setup to iOS connection. |

## iOS Live Demo Flow

1. Start the app in the simulator or on the prepared phone.
2. Open Add Agent.
3. Enter:
   - Name: `Sprint 1 Demo Agent`
   - Agent address: copied `0x...`
   - Endpoint: simulator uses `http://127.0.0.1:8000`; physical phone uses the Mac LAN IP.
4. Save the agent profile.
5. Open the chat for this agent.
6. Send:

```text
Give a concise Sprint 1 connection health check. Mention that the iOS app saved this agent profile, used a signed WebSocket connection, and received your response.
```

Talk track while sending:

> When I tap Send, the ChatViewModel creates an AgentInput and sets the UI to connecting. The client resolves the route. If the direct endpoint is reachable, it uses direct WebSocket; otherwise it can fall back to the relay. The ProtocolCodec signs the CONNECT and INPUT messages using the Keychain-backed identity. When the agent responds, the UI removes the loading state and renders the final message, while conversation state is persisted locally.

Expected visible proof:

- Saved agent appears in the sidebar/list.
- Chat screen shows loading or active status while request runs.
- Agent response appears in the conversation.
- If endpoint is wrong, the app shows a user-facing connection error instead of crashing.

## Backup Plan

- If the relay is unstable, use the direct LAN endpoint.
- If a physical phone cannot reach `localhost`, switch to `http://<Mac-LAN-IP>:8000`.
- If the LLM provider is slow, use the backend `curl` fallback to show the hosted agent is responding, then return to iOS.
- If the iOS app cannot connect during recording, show the error message and explain it as the failure state required by Sprint 1.

## Q&A Prep

- Why SwiftData instead of UserDefaults? Structured agent/conversation records need queryable persistence.
- Why Keychain? Private identity or credential material should not be stored in plain preferences.
- Why WebSocket? Agent sessions need connection status, keep-alive, stream events, and final output.
- Why no custom backend? ConnectOnion already provides `host(agent)`, direct endpoints, and relay routing.
- Why only one feature in live demo? Progressive Demo A should showcase Sprint 1 work; later mobile features are saved for later sprint demos.

## Recording Checklist

- Start backend before screen recording.
- Copy agent address and endpoint into a scratch note.
- Confirm simulator or phone can reach the endpoint.
- Start screen recording with microphone audio.
- Keep live demo linear: backend setup -> iOS save profile -> iOS chat response.
- Submit recording by the course deadline: Week 5 Sunday at 9 PM.

## Additional iOS-Only Live Demo Script - 3.5 Minutes

This version is for the final split where I only present the iOS client side. The backend agent is assumed to have already been created and hosted by the previous presenter.

Speaker script:

> Now I will continue from the iOS client side. Before opening the app itself, I want to briefly show the application icon, because this is also part of the native iOS experience we delivered in Sprint 1. From the home screen, I will point to the ConnectOnion app icon. The logo itself comes directly from the client's official website, so the app keeps the client's existing brand identity instead of inventing a separate visual language. We then adapted it into an iOS app icon using Apple's latest Icon Composer workflow.
>
> I will open Icon Composer for a few seconds here. The important thing I want to show is that the icon is not just a flat imported image. We applied the Liquid Glass effect so that it feels consistent with the latest iOS visual direction. I will switch between the light appearance, dark appearance, and transparent appearance. This lets us check that the icon still has enough contrast and brand recognition in different system contexts, rather than only looking good in one mode.
>
> Next, I will reinstall and launch the app so the audience can see the first-run flow from a clean state. The first screen is the welcome page, which is also the Add Agent page. The design idea here is to keep Sprint 1 focused: if the user does not have an agent connected yet, the app should not take them through empty chat screens or hidden settings. Instead, the first useful action is immediately visible: add the agent address and create a connection.
>
> On this page, I will paste in the agent information created by the backend demo. The agent address identifies the ConnectOnion agent, and the endpoint tells the iOS client where to reach it. Once I save this profile, the app stores the agent configuration locally, so the user does not need to re-enter it every time. For sensitive identity material and connection credentials, we use Keychain rather than plain app preferences, because this data is part of the trust boundary between the phone and the agent.
>
> Now I will try the first connection. On the first attempt, the app asks for an invite code. This behavior intentionally matches the client's existing web experience: the mobile client should not create a different onboarding rule from the product users already know. After I enter the invite code, the app completes the invitation step and we can start the real conversation.
>
> I will now open the chat and type: "What can you do?" While the message is being sent, the UI shows the active connection state. At the top, we can see the agent identity and the connected status. In the conversation area, the user's message appears immediately, then the app shows intermediate agent activity while the backend is reasoning. This is important because AI responses can take a moment, and the user needs feedback that the request is still alive.
>
> When the response returns, the final answer is rendered in the chat view. So the Sprint 1 client-side path is complete: we started from the native app icon, entered the app through the welcome/add-agent flow, saved the hosted agent, handled the invite-code step consistently with the web product, established the connection, sent a real prompt, and displayed the agent's reply. Later sprint demos can expand into more mobile features, but for this checkpoint the key proof is that the iOS client can securely connect to a real ConnectOnion agent and support the first working conversation.

Operation notes:

- Start from the iPhone home screen and tap the app icon only after introducing the icon.
- Open Icon Composer before reinstalling the app; show light, dark, and transparent previews.
- Reinstall or reset app state before the app walkthrough so the welcome/add-agent page appears.
- Use the backend presenter's hosted agent address and endpoint.
- Trigger first connection, enter the invite code, then continue into chat.
- Send exactly: `What can you do?`
- While waiting, point out connected status, user bubble, intermediate activity cards, and final AI response.
