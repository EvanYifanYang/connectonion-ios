# Chat and Conversation Requirements

## Purpose

The Chat module owns persistent conversation behavior, connection orchestration, streamed timeline
state, final reply presentation, recovery, regeneration, latest-turn editing, unread state, and
conversation-level approval mode.

## Desired outcome

Users should experience a durable conversation rather than a raw WebSocket session. They should be
able to understand current progress, leave and return without losing work, recover from failure, and
revise the latest request without corrupting history.

## Scope

- conversation creation and persistence;
- connect/send/reconnect lifecycle;
- optimistic user turn rules;
- server event reduction into timeline items;
- canonical history reconciliation;
- reply streaming/typewriter presentation;
- errors and recovery;
- off-screen completion and unread state;
- copy/share;
- regenerate;
- edit latest user turn;
- conversation title and approval mode.

## Non-goals

- low-level route discovery;
- attachment selection/compression UI;
- remote conversation search;
- multi-user collaborative chats;
- indefinite background execution;
- exposing raw private model reasoning.

## User stories

- As a user, I want my messages and replies to remain after relaunch.
- As a user, I want visible feedback while an agent is connecting and working.
- As a user, I want to leave a chat and find the completed reply later.
- As a user, I want to retry after an ordinary connection interruption.
- As a user, I want to regenerate the latest answer without duplicating history.
- As a user, I want to edit my latest request and replace its exchange safely.
- As a support engineer, I want unsupported events preserved for diagnosis.

## Functional requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| CHAT-001 | P0 | A conversation MUST be associated with exactly one agent address. | A chat cannot be opened against an unrelated agent record. |
| CHAT-002 | P0 | A user turn MUST NOT be persisted as successfully sent if initial connection/send fails. | Failed first connection leaves no misleading optimistic turn. |
| CHAT-003 | P0 | A successfully accepted input MUST persist its visible user content and attachments. | Relaunch restores the user turn in the correct order. |
| CHAT-004 | P1 | Streamed server events MUST update the timeline incrementally. | Tool/thinking/assistant activity appears before final `OUTPUT` when delivered. |
| CHAT-005 | P0 | Event interpretation MUST be deterministic and UI-independent. | Reducer tests can apply events to `[ChatItem]` without SwiftUI. |
| CHAT-006 | P0 | Unknown events MUST remain unknown and retain diagnostic payload. | They are never rendered as fabricated assistant replies. |
| CHAT-007 | P1 | The final server output/canonical state MUST reconcile with local timeline state. | Server-newer data is applied without reopening locally answered cards or dropping unsynchronised local work. |
| CHAT-008 | P1 | Active chat work SHOULD survive in-app navigation. | A retained view model continues receiving and persisting events off-screen. |
| CHAT-009 | P1 | An off-screen completed reply MUST mark the conversation unread. | Opening it while the app is active clears the indicator. |
| CHAT-010 | P0 | Deleting a conversation MUST stop its client and remove runtime ownership. | No retained task, stream, Live Activity, or running badge survives deletion. |
| CHAT-011 | P1 | Reconnection MUST send the stored session context and last rendered event ID when available. | Resume does not blindly start an unrelated session. |
| CHAT-012 | P1 | Regeneration MUST replace the latest eligible exchange rather than append a duplicate user turn. | Successful regeneration has one retained user turn and one replacement answer. |
| CHAT-013 | P0 | Failed, stopped, partial, or empty regeneration MUST restore the original exchange. | No partial regenerated activity replaces a valid completed answer. |
| CHAT-014 | P1 | Latest-turn editing MUST preserve existing attachments unless the user changes them. | Text edit does not silently discard images/files. |
| CHAT-015 | P0 | Failed or stopped latest-turn editing MUST restore the original exchange. | History returns to its exact valid pre-edit state. |
| CHAT-016 | P1 | Edit/regenerate eligibility MUST require a completed, unblocked latest exchange. | Controls are hidden/disabled during active or pending-human-input states. |
| CHAT-017 | P1 | Assistant content MUST be sanitised before display and persistence. | Transport-only reminders/wrappers do not appear as user-facing content. |
| CHAT-018 | P2 | Assistant replies SHOULD expose copy and share actions when content exists. | Actions use the visible sanitised content. |
| CHAT-019 | P1 | Conversation title SHOULD derive from the first meaningful user input until explicitly renamed. | Text, image-only, and file-only starts produce useful default titles. |
| CHAT-020 | P1 | Approval mode MUST persist per conversation and be included in protocol session state. | Relaunch and reconnect preserve Safe/Plan/Accept Edits. |
| CHAT-021 | P1 | A terminal error MUST leave the conversation in a non-working state with a recoverable explanation. | Composer and retry behavior are not indefinitely locked. |
| CHAT-022 | P2 | Reply reveal animation MUST not delay already completed off-screen content when reopened. | Off-screen completed replies render fully on entry. |

## Conversation state model

| State | Meaning | Expected composer behavior |
|---|---|---|
| Idle | No active connection/work | Send enabled if input valid |
| Connecting | Resolving/opening/handshaking | Prevent duplicate send |
| Connected | Handshake complete | Transitional |
| Active | Agent is processing or streaming | Prevent conflicting new turn unless product explicitly supports interruption |
| Waiting | Agent requires human response | Present the relevant card; ordinary send behavior follows current interaction contract |
| Disconnected | Transport is unavailable | Allow clear retry/reconnect path |
| Reconnecting | Resume is in progress | Prevent duplicate resume |

State transitions triggered by server events must be centralised. A view should not independently
invent a session state from visual content.

## Timeline requirements

The timeline may contain:

- user messages;
- assistant messages and images;
- grouped agent activity;
- thinking/model activity;
- tool calls/results;
- ask-user cards;
- approval cards;
- onboarding cards;
- plan-review cards;
- intent;
- evaluation;
- compaction;
- blocked-tool notices;
- received files;
- work-limit notices;
- unknown events.

### Grouping

- Related tool events should form a coherent activity group.
- A tool result arriving before its call must not be dropped or later regressed to running.
- Bare/empty thinking markers should not create meaningless rows.
- A model name should not be misleadingly copied from a previous turn when absent.
- Identical images should not be duplicated across assistant items during event/canonical merges.

### Markdown and code

- Visible assistant content supports Markdown.
- Code fences should retain exact code text.
- Explicit known languages may be syntax highlighted.
- Unknown languages fall back to plain code rendering.
- Highlighting must not mutate copied/shared code.

## Canonical reconciliation rules

When the server provides `chat_items` or session data:

1. sanitise user-visible content;
2. decode known item kinds tolerantly;
3. preserve malformed/unknown items diagnostically;
4. protect locally resolved ask/approval/onboarding/plan cards;
5. preserve a local turn that the server has not yet incorporated;
6. update remote session ID and last-rendered event cursor;
7. persist the resulting stable state.

## Regenerate and edit transaction model

Both operations should behave as local transactions:

1. capture the original eligible exchange and session state;
2. remove/fork only the intended latest exchange;
3. send the replacement input;
4. apply streamed replacement events;
5. commit on a valid non-empty completion;
6. restore the captured state on failure, stop, or invalid empty completion.

This rollback contract is more important than preserving partial failed replacement content.

## Edge cases

- Output arrives without intermediate events.
- Tool result arrives before tool call.
- Server sends a malformed event between valid events.
- Server canonical history contains unknown item kinds/status values.
- A reminder-only assistant event sanitises to empty.
- The user leaves the app while streaming.
- The process is suspended or terminated during a reply.
- A conversation is renamed while active.
- A user deletes the conversation during connection.
- Reconnect returns a server-newer snapshot.
- Regeneration produces partial activity and then fails.
- Edited attachment-only turn has empty text.
- Server output omits model/usage data.

## Non-functional requirements

- Chat state mutation runs on the main actor where required by observable UI state.
- Receive tasks and clients must be cancellable.
- Long timelines should remain scrollable and avoid repeated expensive parsing where possible.
- Error messages should be actionable but must not expose secrets or raw attachment payloads.
- Timeline semantics must remain testable without UI automation.

## Source ownership

Primary sources:

- `Features/Chat/ChatViewModel.swift`
- `Features/Chat/ChatScreen.swift`
- `Features/Chat/ChatTimeline.swift`
- `Features/Chat/ChatItemView.swift`
- `Features/Chat/Timeline/*`
- `Core/ChatLogic/ChatEventReducer.swift`
- `Core/ChatLogic/ChatSessionStore.swift`
- `Core/Models/Chat/*`
- `Core/Persistence/ConversationRecord.swift`

Related tests:

- Sprint 1 event and connection tests;
- Sprint 2 regenerate/edit tests;
- custom-instruction canonical-history tests;
- chat-session-store tests;
- seeded chat UI tests.

## Dependencies

- Network/Protocol supplies typed client events.
- Interactive Workflows defines human-input cards.
- Composer creates `AgentInput`.
- Persistence stores local/canonical state.
- System Integrations mirrors reply progress.

## Future considerations

- Explicit cancel/stop protocol for active agent work.
- Conversation export and retention settings.
- Search within a conversation.
- Pagination or event-store persistence for very long histories.
- Background notification strategy for server-completed work.
- Multi-device canonical session access.

## Definition of done

A Chat change is done when state transitions, persistence timing, reducer behavior, canonical
reconciliation, off-screen lifetime, rollback, sanitisation, errors, accessibility, and automated
coverage are all addressed.
