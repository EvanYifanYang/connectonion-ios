# Network and Protocol Requirements

## Purpose

This document defines the collaboration contract between the iOS client, agent runtime, and relay.
It covers discovery, route selection, WebSocket lifecycle, signed messages, event delivery,
compatibility, and failure behavior.

## Desired outcome

The client should connect to the intended agent over the best available verified route, exchange
compatible signed messages, survive ordinary malformed events, and return actionable errors when it
cannot proceed.

## Scope

- agent address validation;
- direct endpoint probing;
- directory lookup;
- direct-versus-relay route selection;
- URL normalisation;
- WebSocket connection and receive loop;
- `CONNECT`, `INPUT`, response, heartbeat, output, and error messages;
- canonical JSON signing;
- session resume fields;
- attachment frame-size enforcement;
- protocol compatibility rules.

## Non-goals

- relay implementation;
- agent runtime implementation;
- TLS certificate issuance;
- account-based authentication;
- large-file upload;
- push notifications.

## Route requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| NET-001 | P0 | Route resolution MUST reject an invalid agent address. | No network connection is opened for invalid identity input. |
| NET-002 | P1 | A usable preferred endpoint MUST be probed before directory fallback. | Reachable matching `/info` produces a direct route. |
| NET-003 | P0 | Direct `/info` MUST return the exact requested agent address. | Mismatch is rejected and resolution continues/fails safely. |
| NET-004 | P0 | An unreachable preferred endpoint MUST NOT block relay fallback. | A relay-present agent remains connectable. |
| NET-005 | P1 | Advertised direct endpoints SHOULD be tried in proximity order. | Loopback/same-LAN-style candidates precede public candidates where usable. |
| NET-006 | P0 | Physical-device route selection MUST reject loopback as a route to another host. | `localhost`, `127.0.0.1`, and `::1` are not used on device. |
| NET-007 | P1 | Simulator route selection MAY accept loopback for development. | Local test agents remain usable from simulator. |
| NET-008 | P0 | Relay route MUST be used when no direct route succeeds and relay presence is available. | WebSocket URL resolves to relay `/ws/input`. |
| NET-009 | P1 | Route errors MUST preserve the most actionable context. | A configured unreachable endpoint is named when no fallback works. |
| NET-010 | P1 | Directory and probe requests MUST have bounded timeouts. | A dead endpoint does not leave route resolution indefinite. |

## Transport requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| WS-001 | P0 | Each active retained conversation MUST own an independent client/transport. | Starting another chat does not replace the existing receive stream. |
| WS-002 | P0 | Opening a new transport MUST close/cancel any prior transport owned by that client. | One client instance has at most one active socket/receive loop. |
| WS-003 | P0 | Incoming text and UTF-8 data frames MUST be accepted. | Valid JSON from either frame type reaches decoding. |
| WS-004 | P0 | Transport termination MUST finish the async stream exactly once. | Consumers do not hang after close/error. |
| WS-005 | P0 | Server `PING` MUST receive `PONG`. | Heartbeat does not enter the chat reducer. |
| WS-006 | P1 | A malformed non-control event SHOULD be logged and skipped without terminating otherwise valid streaming. | Later valid events still arrive. |
| WS-007 | P0 | `ERROR` MUST terminate the current request with a user-facing failure. | Session leaves active state. |
| WS-008 | P1 | `OUTPUT` MUST complete the current request after yielding final data. | No indefinite receive wait after final output in the current request model. |
| WS-009 | P0 | Disconnect MUST cancel receive work and release transport references. | Deleted/stopped sessions do not retain the socket. |

## Message contract

### `CONNECT`

Required behavior:

- signed canonical payload;
- payload includes current timestamp and target agent;
- top-level type is `CONNECT`;
- includes local/remote session ID;
- includes protocol session object;
- includes `last_msg_id` when available;
- relay route includes target routing information as required.

### `INPUT`

Required behavior:

- unique input ID;
- transmitted prompt;
- timestamp;
- optional images and files;
- session ID;
- relay target where required;
- signed payload contains the same transmitted prompt and timestamp;
- complete encoded frame passes the final maximum-size check.

### Human-response messages

- `ASK_USER_RESPONSE`
- `APPROVAL_RESPONSE`
- `ONBOARD_SUBMIT`
- `PLAN_REVIEW_RESPONSE`

The agent/runtime team must be consulted before fields, signing policy, or response semantics change.

### Server control messages

- `CONNECTED`
- `OUTPUT`
- `ERROR`
- `PING`

All other event types are delegated to the reducer.

## Signing requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| PROTO-001 | P0 | Signed payload JSON MUST use deterministic sorted-key encoding. | Mobile and server produce/verify identical canonical bytes. |
| PROTO-002 | P0 | Signature MUST be Ed25519-compatible and hex encoded as expected by the server. | Protocol fixture verifies successfully. |
| PROTO-003 | P0 | `from` MUST be derived from the signing public key. | Address is `0x` plus the public key hex. |
| PROTO-004 | P0 | The top-level prompt and signed prompt MUST be identical for `INPUT`. | Personalisation wrapping cannot create a signature/content mismatch. |
| PROTO-005 | P1 | Timestamps and input IDs SHOULD support server replay protection. | Server owners document accepted skew and duplicate behavior. |
| PROTO-006 | P0 | Signing failure MUST stop the send before network transmission. | No unsigned substitute is sent. |

## Compatibility requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| PROTO-007 | P0 | Mobile MUST tolerate unknown event types. | Unknown payload is retained diagnostically. |
| PROTO-008 | P1 | Optional profile/session fields MUST decode without requiring a coordinated lockstep release. | Older compatible payloads still work. |
| PROTO-009 | P0 | Breaking message changes MUST have an agreed rollout plan across client, agent, and relay. | Issue/PR records compatibility window and deployment order. |
| PROTO-010 | P1 | New event behavior MUST include server fixtures and iOS reducer tests. | Payload examples are executable or represented in tests. |
| PROTO-011 | P1 | Canonical history fields MUST remain backward-decodable where practical. | Unknown enum values do not crash decoding. |
| PROTO-012 | P1 | Relay URL/path changes MUST be configurable or released with explicit mobile coordination. | Existing app versions retain a supported route during transition. |

## Error classification

Errors should distinguish:

- invalid address;
- preferred endpoint unavailable;
- directory unavailable;
- no reachable direct or relay route;
- transport connection failure;
- malformed handshake/control message;
- signing/identity failure;
- input frame too large;
- server `ERROR`;
- connection interruption while streaming.

Do not reduce every network problem to “No internet connection.” LAN, endpoint, directory, relay,
and protocol failures have different user actions.

## Security constraints

- Production relay uses `wss`/`https`.
- Direct `ws`/`http` is not confidential and requires an explicit product policy.
- A signed payload is authenticated but not encrypted.
- Remote endpoints and QR-provided URLs are untrusted input.
- Logs must not contain private key material or full sensitive payloads.
- The server should enforce timestamp skew, signature validation, and replay protection.

## Edge cases

- Preferred endpoint times out, relay succeeds.
- Directory request succeeds with no relay and unreachable endpoints.
- `/info` returns HTTP 200 with the wrong address.
- WebSocket connects but no `CONNECTED` arrives.
- `PING` arrives before `CONNECTED`.
- Non-control event arrives before `CONNECTED`.
- Malformed event appears between valid tool and output events.
- Output arrives with empty result but canonical chat items.
- Server closes without output/error.
- Combined attachment frame exceeds limit after final JSON encoding.
- Relay base URL includes older `/ws` or `/ws/announce` suffix.

## Observability

Use OSLog categories for route and client diagnostics. Logs should include:

- route class (direct/relay);
- safe endpoint metadata where appropriate;
- error category;
- event type for malformed/unsupported data;
- state transition context.

Logs should exclude prompts, attachment data URLs, answers, invite/payment values, private keys, and
unredacted sensitive tool content.

## Source ownership

Primary sources:

- `Core/Network/Directory/AgentDirectoryService.swift`
- `Core/Network/Directory/AgentRoute.swift`
- `Core/Network/Transport/WebSocketTransport.swift`
- `Core/Network/Client/ConnectOnionClient.swift`
- `Core/Network/Client/ProtocolCodec.swift`
- `Core/Network/Client/ServerEvent.swift`
- `Core/Crypto/KeychainIdentityStore.swift`

Related tests:

- route fallback/direct selection tests;
- signed protocol tests;
- successful and failed connection tests;
- attachment frame tests;
- malformed/unknown event tests;
- optional live-agent E2E.

## Cross-team protocol change process

1. Open one shared change proposal with example JSON.
2. Identify old client, new client, old server, and new server compatibility.
3. Define deployment order and rollback.
4. Add server fixture/contract tests.
5. Add iOS codec/reducer tests and mock event.
6. Deploy tolerant receivers first.
7. Observe compatibility window.
8. Make new fields mandatory only after supported clients are established.

## Future considerations

- Explicit negotiated protocol version.
- Correlation IDs and acknowledgements for every response.
- Configurable relay environments.
- Universal retry/backoff policy.
- Certificate pinning with an operational rotation plan.
- Push-based completion notification.
- Separate attachment transfer service.

## Definition of done

A Network/Protocol change is done when route priority, address verification, timeouts, signing,
message fixtures, backward compatibility, error mapping, logging privacy, mocks, agent/relay
coordination, and rollout order are documented and tested.
