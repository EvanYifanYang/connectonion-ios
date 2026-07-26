# Product Foundations

## Purpose

This document defines the stable product intent that all ConnectOnion iOS modules should serve. It
is the baseline for prioritisation and for resolving disagreements between locally convenient
implementation choices and the intended user experience.

## Product statement

ConnectOnion iOS is a native mobile client that lets a person discover, manage, and communicate with
ConnectOnion agents while retaining meaningful control over agent actions and understanding the
agent's live progress.

## Desired outcomes

The product should enable users to:

- connect to an agent with minimal configuration;
- return to persistent conversations;
- understand whether an agent is available and what it can do;
- send natural-language requests and supported attachments;
- observe meaningful progress without reading raw protocol data;
- approve, reject, revise, or answer an agent when human input is required;
- continue using the app while a reply is in progress;
- trust that their local client identity remains stable;
- recover from ordinary network and protocol failures without losing valid conversation state.

## Primary users

### Agent user

A person who wants to ask an agent to perform knowledge or tool-assisted work from an iPhone or
iPad. They may understand the agent's domain but should not need to understand WebSockets, relays, or
cryptographic envelopes.

### Agent operator

A person who hosts or configures a ConnectOnion agent and provides its address, endpoint, or QR code
to users. They need predictable discovery and protocol compatibility.

### Product support or developer

A person who diagnoses connection, identity, protocol, UI, or persistence problems. They need useful
errors and stable requirement/test references.

## Product principles

1. **Agent-first organisation.** The agent is the top-level object; conversations belong to an
   agent.
2. **Human control remains visible.** Approval and required-input states must not be hidden in
   generic messages.
3. **Progress should be understandable.** Tool and model activity should be reduced into typed,
   readable timeline units.
4. **Local continuity matters.** Navigation should not discard active work, and completed work
   should be available on return.
5. **Protocol failures should be diagnosable.** Unknown or malformed data must not silently become
   plausible but incorrect assistant content.
6. **Direct when possible, relay when necessary.** Connectivity should favour a verified direct
   path without making it a single point of failure.
7. **Identity is device-held.** The private signing identity should not leave secure device storage.
8. **System integrations are shortcuts, not separate products.** Widgets and Live Activities should
   lead users back to the authoritative app state.

## In scope

- agent add, edit, scan, list, search, pin, and delete;
- remote agent profile and status display;
- local persistent conversations;
- text, photo, camera, file, and dictated input;
- direct and relay WebSocket communication;
- signed connect and input messages;
- streamed event timeline;
- approvals, ask-user input, plan review, and onboarding;
- reply regeneration and latest-turn editing;
- personalisation and display settings;
- widget shortcuts, deep links, and reply Live Activities;
- mock-based unit/UI testing and optional live-agent E2E validation.

## Non-goals

- hosting the agent runtime in the iOS app;
- executing remote agent tools locally;
- operating the public relay;
- providing a general file-transfer service;
- providing an account-based multi-device sync service;
- guaranteeing indefinite background network execution;
- replacing server-side authorization or tool safety controls;
- exposing raw model chain-of-thought;
- supporting OS versions below the project's iOS 26 baseline.

## Global functional requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| PROD-001 | P0 | The app MUST organise conversations under saved agents. | A conversation always references an agent address and is opened through that agent context. |
| PROD-002 | P0 | The app MUST preserve valid local conversation state across ordinary launches. | Saved agents and conversations restore after process termination and relaunch. |
| PROD-003 | P0 | The app MUST keep the user's private signing key out of ordinary app persistence and shared widget data. | The key is stored through Keychain only and is absent from SwiftData/App Group snapshots. |
| PROD-004 | P0 | The app MUST distinguish user decisions from passive agent output. | Approvals, questions, onboarding, and plan review use dedicated interactive UI. |
| PROD-005 | P0 | The app MUST fail safely when it cannot establish or authenticate the intended route. | No optimistic user turn is retained as successfully sent after a connection failure. |
| PROD-006 | P1 | The app SHOULD retain active reply work when the user navigates elsewhere in the app. | Returning to the conversation shows continued or completed activity. |
| PROD-007 | P1 | The app MUST make direct and relay route failures understandable to non-network specialists. | Errors name the relevant endpoint, reachability, or directory problem where known. |
| PROD-008 | P1 | The app MUST preserve unsupported server events for diagnosis. | Unknown events do not become assistant messages and retain their type/raw payload. |
| PROD-009 | P1 | The app SHOULD provide a complete usable flow without requiring system integrations. | Core agent/chat behavior works if widget and Live Activities are unavailable. |
| PROD-010 | P1 | The app MUST respect declared agent input capabilities where provided. | Unsupported composer actions are hidden, disabled, or rejected with an explanation. |
| PROD-011 | P2 | The app SHOULD present local aliases independently from server-owned names. | A local alias remains the primary display name without overwriting remote metadata. |
| PROD-012 | P2 | The app SHOULD provide accessible alternatives for animated, visual, and gesture-based interactions. | Core actions remain labelled, discoverable, and operable with VoiceOver and reduced motion. |

## Cross-cutting states

### Connectivity

- online;
- offline;
- probing/unknown;
- connecting;
- connected;
- disconnected;
- reconnecting;
- failed.

Status shown at agent-list level is advisory. It must not be treated as a guarantee that a new chat
connection will succeed.

### Conversation activity

- idle;
- connecting;
- connected;
- active;
- waiting for human input;
- disconnected;
- reconnecting;
- completed with unread result.

### Data authority

- local aliases and pin state are client-owned;
- agent profile and capabilities are server-owned and cached locally;
- the local timeline is the immediate presentation state;
- a compatible server canonical snapshot may supersede/reconcile remote session content;
- locally answered cards and unsynchronised local turns must not be accidentally reopened or lost.

## Global non-functional requirements

### Reliability

- ordinary navigation must not cancel an active reply;
- one malformed streamed event should not necessarily terminate the whole reply;
- deleting a conversation must stop its retained client session;
- retry paths must avoid duplicate optimistic user messages.

### Performance

- common navigation and local list operations should feel immediate;
- streamed events should update incrementally;
- expensive syntax highlighting and image processing should not block typing or scrolling;
- long timelines should avoid unnecessary full recomputation where practical.

### Privacy

- no production secret should be committed to the repository;
- logs should avoid prompt, attachment, credential, and private-key content;
- permission requests should occur in context and use accurate purpose strings;
- new personal-data flows require privacy review.

### Compatibility

- mobile, agent, and relay changes must be deployed in a backward-compatible order;
- encoded enum and event handling should remain tolerant of unknown values;
- breaking SwiftData changes require migration planning.

## Product success signals

The current repository does not implement a product analytics service. Until the client approves a
privacy-reviewed analytics plan, product success should be assessed through:

- task-based usability testing;
- connection and completion success in controlled QA;
- support issue categories;
- crash-free and hang-free sessions if crash reporting is introduced;
- App Store/TestFlight feedback;
- protocol compatibility test results.

Do not add tracking merely to satisfy this list. Analytics requirements need purpose, consent,
retention, and data-owner decisions.

## Open product decisions

- Whether the production app permits insecure `http`/`ws` direct endpoints.
- Whether identity remains intentionally device-local or gains a recovery/transfer mechanism.
- Whether conversation export, clear-all, and retention controls are required.
- Whether the app will support Universal Links in addition to the custom URL scheme.
- Whether larger attachments move to a separate upload service.
- Whether multiple relay environments are selectable by users, operators, or build configuration.
- Whether localisation beyond English is in scope.

## Definition of done for cross-cutting changes

A cross-cutting product change is done when:

- intended behavior and non-goals are explicit;
- affected module requirement IDs are updated;
- protocol and persistence impacts are resolved;
- permission, privacy, accessibility, and system-integration impacts are reviewed;
- deterministic automated coverage is added where feasible;
- visible behavior has review evidence;
- GitHub Actions passes on the pushed commit;
- release notes identify any operator or user action.
