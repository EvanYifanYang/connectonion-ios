# Data, Identity, and Security Requirements

## Purpose

This document defines local data ownership, persistence behavior, client identity, signing-key
handling, privacy boundaries, deletion expectations, and migration responsibilities.

## Scope

- SwiftData agent and conversation records;
- encoded timeline and raw session storage;
- Keychain private-key storage;
- client identity derivation and regeneration;
- AppStorage/UserDefaults preferences;
- App Group snapshot data boundary;
- data deletion;
- model/schema migration;
- privacy-sensitive logging and diagnostics.

## Non-goals

- server-side storage policy;
- account-based cloud sync;
- private-key escrow;
- full mobile threat-model certification;
- relay data retention implementation.

## Data classification

| Data | Classification | Storage | Owner |
|---|---|---|---|
| Ed25519 private key | Secret | Keychain | Device user |
| Public client address | Identifier | Derived/displayed | Device user |
| Agent address/endpoint | Configuration | SwiftData | User |
| Local agent alias/pin | User preference | SwiftData | User |
| Remote profile cache | External metadata | SwiftData encoded data | Agent/operator |
| Conversation text | Potentially sensitive content | SwiftData encoded data | User + remote agent context |
| Images/files in history | Potentially sensitive content | Encoded conversation data | User |
| Raw server session | Protocol/session data | SwiftData encoded data | Shared protocol state |
| Appearance/personalisation | Preference; custom text may be sensitive | UserDefaults/AppStorage | User |
| Widget shortcut snapshot | Limited shared metadata | App Group UserDefaults | User |

## Persistence requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| DATA-001 | P0 | Saved agents and completed conversation state MUST survive ordinary app relaunch. | Persistent container restores records. |
| DATA-002 | P0 | The private signing key MUST NOT be stored in SwiftData, ordinary UserDefaults, files, logs, or widget snapshots. | Key material exists only through the Keychain adapter. |
| DATA-003 | P0 | Conversation records MUST retain agent address, session identifiers, messages, mode, and resume cursor needed for restoration. | Relaunch/reconnect has sufficient state. |
| DATA-004 | P1 | Unknown chat items and raw payloads SHOULD remain encodable for diagnosis and forward compatibility. | Decode/encode round trip does not discard unsupported event identity. |
| DATA-005 | P1 | Local alias, pin state, unread state, and explicit conversation title MUST remain client-owned. | Server profile/session updates do not overwrite them unintentionally. |
| DATA-006 | P0 | Deleting a conversation MUST remove its persistent record and retained runtime session. | It is absent after relaunch and no active client remains. |
| DATA-007 | P0 | Deleting an agent MUST resolve dependent conversations according to the confirmed product behavior. | No inaccessible orphan records remain. |
| DATA-008 | P1 | Widget sharing MUST use a minimal snapshot rather than the full conversation store. | Snapshot contains only documented shortcut fields. |
| DATA-009 | P0 | Breaking persistence changes MUST include an explicit migration plan before release. | Upgrade from prior production schema is tested. |
| DATA-010 | P1 | Corrupt optional encoded cache data SHOULD degrade gracefully. | Agent/profile cache failure does not prevent app launch. |
| DATA-011 | P0 | Corrupt required persistent state MUST produce a controlled recovery strategy before production. | The app does not rely only on an unexplained fatal termination for known migration/corruption cases. |
| DATA-012 | P2 | Data growth from attachments and long timelines SHOULD be measured. | Team can identify store-size/performance regressions before release. |

## Identity requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| ID-001 | P0 | First identity access MUST load a valid existing private key or generate a new key. | Same installation returns a stable client address. |
| ID-002 | P0 | Private key storage MUST use `AfterFirstUnlockThisDeviceOnly` or an approved stronger policy. | Key is not synchronised through ordinary cloud Keychain behavior. |
| ID-003 | P0 | Invalid stored key bytes MUST not be silently replaced during the same operation. | Error is surfaced after removing/handling invalid material according to policy. |
| ID-004 | P0 | Client address MUST be deterministically derived from the public key. | Address remains `0x` plus public-key hex. |
| ID-005 | P0 | Identity regeneration MUST require an intentional user action and explain continuity impact. | User understands that remote recognition may change. |
| ID-006 | P0 | Signing MUST fail closed. | No unsigned fallback message is sent. |
| ID-007 | P1 | Bundle/signing changes MUST be tested for Keychain continuity. | Upgrade validation confirms whether the prior identity remains accessible. |

## SwiftData model contract

### Agent

Required durable fields:

- address;
- alias;
- preferred endpoint;
- created/updated/last-connected timestamps;
- cached remote profile data;
- pin timestamp.

### Conversation

Required durable fields:

- local UUID;
- agent address;
- remote session ID;
- title and timestamps;
- approval mode raw value;
- encoded messages;
- encoded raw session;
- last rendered event ID;
- pin timestamp;
- unread flag.

### Encoded-blob trade-off

The timeline/session blob simplifies polymorphic protocol persistence but makes:

- per-message querying difficult;
- partial updates less efficient;
- attachment-heavy stores large;
- migrations dependent on tolerant Codable behavior.

Changes to `ChatItem`, enum raw values, or nested payloads require old-data fixtures.

## Migration process

For every persistent model change:

1. identify the latest production schema;
2. classify the change as additive-compatible or breaking;
3. define a versioned schema/migration stage where required;
4. preserve tolerant decoding for historical enum/payload values;
5. create a previous-version store fixture;
6. test upgrade with messages, attachments, unknown events, pins, and unread state;
7. test widget/App Group behavior separately;
8. document downgrade expectations;
9. validate on TestFlight over an installed prior build.

## Deletion and retention

Current deletion is local. The team must not imply that deleting a local conversation also deletes
server/agent/relay copies unless a confirmed protocol exists.

Future retention controls should separately define:

- delete one conversation locally;
- delete all conversations locally;
- delete an agent and dependent local data;
- clear cached profile data;
- reset preferences;
- regenerate/reset identity;
- request remote deletion;
- export before deletion.

## Security requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| SEC-001 | P0 | Logs MUST exclude private keys and full sensitive payloads. | Logging review finds no key, prompt, attachment data URL, password, or invite/payment leakage. |
| SEC-002 | P0 | Production external routes SHOULD use TLS. | Relay is `wss`/`https`; insecure direct-route policy is explicit. |
| SEC-003 | P0 | Remote and QR-provided content MUST be treated as untrusted input. | URL/address validation and safe rendering are applied. |
| SEC-004 | P0 | App permissions MUST accurately describe actual data use. | Info.plist, App Privacy answers, and privacy policy remain aligned. |
| SEC-005 | P1 | Sensitive interaction fields MUST not be persisted into visible history unless required. | Password-style answers remain masked and absent from logs. |
| SEC-006 | P1 | Shared extension data MUST follow data minimisation. | Widget receives no conversations or signing secret. |
| SEC-007 | P0 | A new third-party SDK handling user data requires privacy/security review. | Purpose, fields, retention, processors, and consent are documented before merge. |

## Edge cases

- Keychain item exists but is invalid.
- App is reinstalled.
- Bundle ID, Team ID, or Keychain entitlement changes.
- SwiftData store was created by an older enum schema.
- Cached profile blob is corrupt.
- Conversation blob is partially corrupt.
- An attachment makes a single conversation very large.
- Deletion occurs while a model is visible or streaming.
- App Group identifier changes.
- A user expects local deletion to delete remote history.

## Source ownership

Primary sources:

- `Core/Persistence/AgentConfigRecord.swift`
- `Core/Persistence/ConversationRecord.swift`
- `Core/Persistence/KeychainCredentialStore.swift`
- `Core/Crypto/KeychainIdentityStore.swift`
- `Core/Crypto/ClientIdentity.swift`
- `Core/Crypto/SignedEnvelope.swift`
- `Core/Models/Chat/*`
- `ConnectOnionShared/ConnectOnionSharedData.swift`

Related tests:

- signed payload tests;
- custom-history sanitisation tests;
- unknown enum/item decode tests;
- persistence behavior exercised through chat tests;
- widget snapshot encoding tests.

## Cross-team dependencies

- Client release owner controls signing and identifiers.
- Agent/relay owners disclose remote retention.
- Product/legal own privacy policy and deletion claims.
- Security approves new secrets, identity transfer, analytics, and payment flows.
- QA owns upgrade fixtures and TestFlight migration validation.

## Future considerations

- Versioned SwiftData migration plan.
- Conversation storage size controls.
- User-facing export/clear-all.
- Optional protected-data state handling before first unlock.
- Identity transfer/recovery with a separately approved security design.
- App-level encryption for compliance-specific deployments.

## Definition of done

A Data/Identity change is done when ownership, storage class, migration, deletion semantics, Keychain
continuity, shared-data exposure, privacy copy, logging, security review, and upgrade tests are
complete.
