# ConnectOnion iOS Internal Product Documentation

## Purpose

This directory contains the working product requirements and module contracts used by the
ConnectOnion iOS team. These documents support day-to-day collaboration between product, design,
iOS, agent/runtime, relay, QA, security, and release contributors.

They are intentionally more actionable than basic design documents or meeting notes. Each module
document records the behavior the team is expected to preserve, the acceptance criteria for changes,
important edge cases, source ownership, and cross-team dependencies.

For system architecture, production ownership, signing, and client handover, see
[`../CLIENT_HANDOVER.md`](../CLIENT_HANDOVER.md).

## How to use this documentation

Use these documents when:

- defining a feature or bug-fix issue;
- deciding whether behavior is intended or accidental;
- reviewing a pull request;
- coordinating a mobile/server protocol change;
- writing acceptance tests;
- planning a release;
- onboarding a new team member;
- recording a product decision that should survive beyond a meeting.

Do not use these documents as a substitute for:

- the implementation, which remains authoritative for the current build;
- protocol fixtures and automated tests;
- security review;
- App Store release records;
- time-bound sprint plans or meeting minutes.

## Document map

| Document | Primary collaboration topic |
|---|---|
| [`01-product-foundations.md`](01-product-foundations.md) | Product goals, users, principles, scope, global requirements |
| [`02-shell-and-navigation.md`](02-shell-and-navigation.md) | App launch, navigation hierarchy, search, pinning, rename/delete flows |
| [`03-agent-management.md`](03-agent-management.md) | Add/edit/scan agents, profile data, status, capabilities |
| [`04-chat-and-conversations.md`](04-chat-and-conversations.md) | Conversation lifecycle, timeline, streaming, resume, regenerate/edit |
| [`05-composer-and-input.md`](05-composer-and-input.md) | Text, attachments, camera/photos/files, voice, validation |
| [`06-interactive-agent-workflows.md`](06-interactive-agent-workflows.md) | Approvals, ask-user, plan review, onboarding, tool activity |
| [`07-network-and-protocol.md`](07-network-and-protocol.md) | Discovery, direct/relay routing, WebSocket contract, compatibility |
| [`08-data-identity-and-security.md`](08-data-identity-and-security.md) | SwiftData, Keychain identity, signing, privacy, deletion |
| [`09-system-integrations.md`](09-system-integrations.md) | Widget, App Group, deep links, Live Activity |
| [`10-settings-design-and-accessibility.md`](10-settings-design-and-accessibility.md) | Appearance, personalisation, code display, design system, accessibility |
| [`11-quality-release-and-collaboration.md`](11-quality-release-and-collaboration.md) | Test strategy, CI, definition of done, release and cross-team workflow |

## Requirement language

The words **MUST**, **SHOULD**, and **MAY** are used deliberately:

- **MUST** — required for correctness, safety, compatibility, or release acceptance.
- **SHOULD** — expected behavior; exceptions require a documented reason.
- **MAY** — optional behavior that can be implemented without changing the core contract.

Requirement identifiers are stable references. For example:

- `AGT-004` refers to an agent-management requirement.
- `CHAT-012` refers to a chat requirement.
- `NET-007` refers to a network requirement.

Do not renumber existing requirements after they are referenced in an issue, test, or pull request.
Mark obsolete requirements as deprecated and link to their replacement.

## Priority model

| Priority | Meaning |
|---|---|
| P0 | Required for a valid, secure, or usable release |
| P1 | Core product behavior expected in the release |
| P2 | Important refinement, resilience, or usability behavior |
| P3 | Optional enhancement or future consideration |

Priority describes product importance, not implementation effort.

## Standard module document structure

Each module document should contain:

1. purpose and desired outcome;
2. scope and non-goals;
3. users and user stories;
4. functional requirements with stable IDs;
5. state and interaction rules;
6. edge cases and failure behavior;
7. non-functional requirements;
8. source and test ownership;
9. cross-team dependencies;
10. open decisions or future work;
11. a module-specific definition of done.

## Current behavior versus future requirements

These documents primarily describe the current product contract. Future ideas must be placed under
an explicit **Future considerations** or **Open decisions** heading. A proposed behavior is not an
accepted requirement until product, engineering, and any affected protocol owner agree to it.

When current code does not meet a documented `MUST` requirement:

1. create an issue referencing the requirement ID;
2. label the gap as a defect, documentation error, or approved product change;
3. update either the implementation or the requirement;
4. add or adjust automated coverage;
5. record compatibility and release impact.

## Traceability in issues and pull requests

Feature issues should include:

```text
Requirements: CHAT-004, CHAT-008
Affected modules: Chat, Persistence
Protocol impact: None
Migration impact: None
Acceptance evidence: Unit tests + UI scenario + screenshots
```

Pull requests should state:

- requirement IDs implemented or changed;
- visible behavior before and after;
- affected targets;
- protocol, persistence, entitlement, privacy, or accessibility impact;
- local compile checks performed;
- expected GitHub Actions coverage;
- screenshots or recordings for visible UI changes.

## Updating these documents

Update a module document in the same pull request when a change:

- adds or removes user-facing behavior;
- changes an acceptance criterion;
- changes a protocol field or event;
- changes persistent data or migration requirements;
- adds a permission, entitlement, or external service;
- changes an error or recovery path;
- changes release or testing responsibility;
- resolves an open product decision.

Meeting notes may link to these files, but durable decisions must be incorporated here.

## Cross-module change checklist

Before implementation begins, ask:

- Does the change affect the agent/runtime protocol?
- Does it require a backward-compatible rollout?
- Does it alter a SwiftData model or encoded payload?
- Does it change Keychain, signing, bundle IDs, or App Group access?
- Does it add a permission or privacy disclosure?
- Does it add a new timeline item or interactive card?
- Does it need deep-link, widget, or Live Activity behavior?
- Does it affect background/session lifetime?
- Does it require new accessibility identifiers?
- Does it need unit, UI, E2E, or migration coverage?

## Documentation ownership

The module owner implementing a change is responsible for keeping the relevant document accurate.
Product owns intended user behavior and priority. Engineering owns feasibility, technical
constraints, and compatibility. QA owns acceptance coverage. Security/privacy owners approve changes
to trust boundaries and personal data handling.

Every contributor is expected to flag documentation that no longer matches the product.
