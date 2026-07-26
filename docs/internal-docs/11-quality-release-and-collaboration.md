# Quality, Release, and Collaboration Requirements

## Purpose

This document defines how the team turns requirements into reviewed, testable, releasable changes.
It provides a shared definition of done across product, design, iOS, agent/runtime, relay, QA,
security, and release owners.

## Quality objectives

- protect identity, persistence, and protocol compatibility;
- catch regressions in human-control workflows;
- keep UI behavior deterministic under mock data;
- validate real connectivity where mocks are insufficient;
- make release ownership and evidence explicit;
- avoid documentation becoming detached from implementation.

## Test layers

| Layer | Purpose | Typical ownership |
|---|---|---|
| Pure unit | Address, encoding, parsing, reducer, preferences | iOS developer |
| Mock client/service | View-model transactions, rollback, reconnection | iOS developer |
| UI test | User navigation and interactive behavior | iOS + QA |
| Real-agent E2E | Client/runtime/relay compatibility | iOS + agent/runtime |
| Manual device | Permissions, camera, speech, LAN, Widget, Live Activity, accessibility | QA/release |
| Migration/upgrade | Production data continuity | iOS + QA/release |

## Repository test policy

The repository's `AGENTS.md` requires:

- do not run tests locally after code changes unless the user explicitly requests a specific test or
  debug run;
- prefer local build/compile checks while iterating;
- run all unit and UI tests after push in GitHub Actions through
  `.github/workflows/ios-tests.yml`.

Contributors and automated agents must follow this policy until it is deliberately changed by the
project owner.

## Quality requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| QA-001 | P0 | Every behavior change MUST reference affected requirement IDs or explain why none apply. | Issue/PR contains traceability. |
| QA-002 | P0 | Protocol changes MUST include deterministic payload/event fixtures or tests. | Codec/reducer behavior can be verified without a live server. |
| QA-003 | P0 | Persistence changes MUST include upgrade/migration evidence before release. | Prior-version data opens correctly. |
| QA-004 | P0 | Human-control workflows MUST have failure and retry coverage, not only happy path. | Approval/ask/onboarding/plan states recover correctly. |
| QA-005 | P1 | Visible feature changes SHOULD include UI automation where stable and cost-effective. | Critical user flow has repeatable coverage. |
| QA-006 | P0 | A pushed release candidate MUST have a green `iOS Tests` workflow. | GitHub Actions conclusion is success for the exact commit. |
| QA-007 | P1 | Flaky tests MUST be investigated rather than permanently masked by retries. | Issue records root cause/owner when retry rate becomes meaningful. |
| QA-008 | P0 | App and Widget targets MUST compile after shared-model or entitlement changes. | Release compile/archive succeeds for both. |
| QA-009 | P1 | Physical-device-only behavior MUST have recorded manual evidence. | Camera, LAN, speech, Widget, Live Activity, or signing validation is attached/checklisted. |
| QA-010 | P1 | Accessibility acceptance MUST be part of visible feature review. | VoiceOver/Dynamic Type/reduced-motion impact is recorded. |
| QA-011 | P0 | Secrets and sensitive payloads MUST be absent from commits and test logs. | Review/scanning finds no credential/private data. |
| QA-012 | P1 | Internal module documentation MUST change with durable product-contract changes. | Relevant requirement/edge case/source map stays accurate. |

## Current automated coverage map

### Unit and service tests

- address normalisation;
- signed connect/input protocol;
- direct and relay route selection;
- QR parsing;
- event reduction;
- out-of-order tools;
- ask-user, approval, onboarding, plan review;
- unknown events and tolerant decoding;
- custom-instruction wrapping/sanitisation;
- attachments and frame budgets;
- regeneration and latest-turn editing rollback;
- session-store unread/lifetime;
- widget snapshots and deep links;
- personalisation and syntax highlighting.

### UI tests

- seeded and empty launch;
- streaming message flow;
- edit/regenerate;
- attachment entry points;
- agent landing/capabilities/suggestions;
- agent add/rename/delete;
- conversation rename/delete;
- approval, ask-user, onboarding, plan review;
- sidebar access.

### E2E

The real-agent test is intentionally separate because it requires a live compatible agent. Use
`scripts/run_e2e.sh` and follow `scripts/README.md`.

## Definition of ready

Work is ready for implementation when:

- problem and desired user outcome are clear;
- in-scope and non-goal boundaries are written;
- requirement IDs and acceptance criteria exist;
- affected modules and owners are identified;
- protocol/persistence/security/privacy/entitlement impact is classified;
- design states include loading, empty, error, and accessibility behavior;
- rollout/compatibility approach exists for cross-repository changes;
- unresolved product decisions are explicitly assigned.

## Pull request requirements

Every substantive PR should include:

1. summary and user impact;
2. requirement IDs;
3. screenshots/recording for visible behavior;
4. affected targets/modules;
5. protocol impact and example payloads;
6. persistence/migration impact;
7. privacy/security/permission/entitlement impact;
8. accessibility impact;
9. compile checks performed;
10. expected CI coverage;
11. rollout or operator steps;
12. internal documentation updates.

Reviewers should verify claims against the diff rather than relying only on the PR description.

## Cross-team change workflow

### Mobile-only behavior

1. Product confirms requirement.
2. Design supplies states where visible.
3. iOS implements with mocks.
4. QA/reviewer validates acceptance and accessibility.
5. Push triggers GitHub Actions.
6. Merge only with required approval/checks.

### Protocol behavior

1. Shared proposal includes old/new JSON examples.
2. Mobile, agent, and relay owners review compatibility.
3. Tolerant receiver changes deploy first.
4. Fixtures/tests land in each affected repository.
5. E2E validates the version matrix.
6. Mandatory sender behavior deploys after the compatibility window.

### Persistence behavior

1. Data owner defines old/new schema.
2. Migration and recovery are implemented.
3. Previous-version store fixture is tested.
4. TestFlight upgrade validates real signing/container behavior.
5. Release notes identify irreversible effects.

## GitHub Actions requirements

The current workflow:

- triggers on push and manual dispatch;
- selects Xcode 26 when available;
- runs on the latest compatible macOS runner;
- uses an iPhone 17 Pro simulator with latest OS;
- disables parallel testing;
- allows up to three iterations for transient UI-runner timing;
- has a 60-minute timeout.

Workflow maintenance rules:

- Pin or deliberately review major action versions.
- Treat runner/Xcode updates as release-infrastructure changes.
- Keep the simulator destination available on hosted runners.
- Do not add production secrets to test output.
- Investigate repeated retries/timeouts.
- Preserve unit/UI execution after push unless the owner approves a replacement.

## Release requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| REL-001 | P0 | Release MUST use client-owned Apple signing and App Store access. | Archive validates under the intended team. |
| REL-002 | P0 | Marketing version/build number MUST identify the uploaded binary uniquely. | App Store Connect accepts the build and release record matches commit/tag. |
| REL-003 | P0 | App and Widget identifiers/App Group MUST be aligned in project, entitlements, portal, and profiles. | Widget data and archive validation succeed. |
| REL-004 | P0 | Exact release commit MUST have green CI. | Workflow URL is recorded. |
| REL-005 | P0 | Release candidate MUST pass physical-device smoke testing. | Direct/relay chat and critical human-input flow complete. |
| REL-006 | P1 | Widget and Live Activity MUST be validated on supported hardware. | Start/update/end/deep-link behavior is recorded. |
| REL-007 | P0 | Privacy disclosures and permission purpose strings MUST match the binary. | Store answers, policy, and plist are reviewed. |
| REL-008 | P0 | Upgrade from the previous release MUST be validated when persistent schema or signing changes. | Existing identity and conversations behave according to plan. |
| REL-009 | P1 | Release notes MUST identify agent/runtime compatibility and operator actions. | Support team receives the matrix before rollout. |
| REL-010 | P1 | Released commit SHOULD be tagged and linked to the App Store build. | Incident response can identify exact source. |

## Release smoke checklist

- Add an agent manually.
- Scan a supported agent QR code.
- Refresh profile and capabilities.
- Connect through a verified direct endpoint.
- Exercise relay fallback.
- Send text.
- Send image/file within limits.
- Complete approval and ask-user flow.
- Validate onboarding/plan review if present in the release scope.
- Navigate away during a reply and verify unread completion.
- Regenerate/edit latest turn.
- Relaunch and restore state.
- Validate light/dark and large text.
- Check denied/granted permissions.
- Check widget and deep links.
- Check Live Activity lifecycle.
- Inspect logs for sensitive data.

## Defect severity guidance

| Severity | Examples |
|---|---|
| Blocker | Data loss, private-key exposure, wrong-agent routing, unusable launch, invalid release signing |
| Critical | Approval sent incorrectly, conversation corruption, no send/receive, migration failure |
| Major | Broken attachment/voice workflow, stale running session, inaccessible core action |
| Minor | Visual inconsistency, non-blocking copy issue, low-impact animation defect |

Severity does not replace product priority; it helps incident and release decisions.

## Incident collaboration

For connectivity/protocol incidents, record:

- app version/build and commit;
- iOS/device;
- agent/runtime version;
- relay environment;
- direct or relay route;
- safe timestamps and error category;
- whether `/info`, handshake, events, or output failed;
- whether retry/reconnect worked;
- redacted diagnostic logs.

Do not request private keys, raw sensitive prompts, password answers, or unredacted attachment data
in ordinary support channels.

## Documentation review cadence

- Update module docs in the feature PR.
- Review the index and open decisions at each major release boundary.
- Perform a full handover/internal-doc accuracy review when ownership changes.
- Deprecate obsolete requirements explicitly.
- Convert durable meeting decisions into requirements within the same sprint.

## Definition of done

Work is done when:

- acceptance criteria are met;
- code and internal docs agree;
- affected targets compile;
- local activity follows repository test policy;
- pushed GitHub Actions is green;
- protocol/persistence/security/accessibility impacts are resolved;
- visible evidence is reviewed;
- rollout and release notes are ready;
- no known blocker remains hidden in a meeting note or chat thread.
