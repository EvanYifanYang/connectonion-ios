# System Integration Requirements

## Purpose

This document defines the product contract for the Widget, App Group snapshot, custom deep links,
Live Activity, Dynamic Island, and the app-side coordination that keeps these surfaces consistent.

## Desired outcome

System surfaces should provide fast, privacy-conscious shortcuts and status while always returning
the user to the authoritative app experience.

## Scope

- App Group data sharing;
- small/medium home-screen widget;
- empty and populated widget states;
- agent shortcuts and suggestions;
- `connectonion://` URL parsing;
- scanner, new-chat, and conversation deep links;
- reply Live Activity;
- Lock Screen and Dynamic Island presentation;
- ActivityKit lifecycle.

## Non-goals

- independent conversation execution inside the widget;
- full chat history in App Group storage;
- guaranteed background processing;
- public-web Universal Links;
- push notifications.

## Widget requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| WDG-001 | P0 | Widget data MUST be a minimal encoded snapshot in the shared App Group. | No private key or full conversation content is shared. |
| WDG-002 | P1 | Empty widget state MUST direct the user to add/scan an agent. | Tap opens the scanner flow in the app. |
| WDG-003 | P1 | Populated widget state MUST expose a valid new-chat shortcut. | Tap routes to the intended saved agent. |
| WDG-004 | P1 | Suggested prompt links MUST preserve both agent address and suggestion text. | App opens the correct new-chat context. |
| WDG-005 | P1 | Medium widget SHOULD show a bounded number of useful agent shortcuts. | Layout remains readable and does not imply the full list is shown. |
| WDG-006 | P1 | Widget snapshot publication MUST follow meaningful source changes. | Agent add/edit/delete, profile/display, and recent use changes can refresh the widget. |
| WDG-007 | P2 | Widget rendering MUST support light/dark appearance and Dynamic Type constraints appropriate to WidgetKit. | Text remains legible and key action is not clipped. |
| WDG-008 | P1 | Missing/corrupt snapshot data MUST fall back to a safe empty state. | Widget does not crash. |

## Deep-link requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| LINK-001 | P0 | Only the registered `connectonion` scheme and supported hosts MUST be accepted. | Foreign/unknown URLs are rejected. |
| LINK-002 | P1 | New-chat links MUST parse an agent address and optional suggestion. | Round-trip tests preserve encoded text. |
| LINK-003 | P1 | Conversation links MUST parse a local UUID string. | Existing local conversation opens. |
| LINK-004 | P1 | Scanner links MUST open scanner presentation. | Empty-agent widget action reaches scanner. |
| LINK-005 | P0 | Invalid/stale link data MUST not crash or corrupt navigation. | App remains at a valid shell destination. |
| LINK-006 | P1 | Deep-link handling MUST avoid duplicate route pushes when the destination is already active. | Repeated link activation produces one coherent stack. |
| LINK-007 | P1 | Links MUST not bypass agent/address validation for data creation. | A link cannot silently save an unvalidated agent. |

Supported forms:

```text
connectonion://new-chat?agent={address}
connectonion://new-chat?agent={address}&suggestion={text}
connectonion://conversation?id={local-uuid}
connectonion://scan-agent
```

Conversation links are installation-local. This limitation must be understood before using them in
external communication.

## Live Activity requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| LIVE-001 | P1 | An active reply MAY start one Live Activity tied to the conversation and agent. | Attributes contain stable conversation/agent context. |
| LIVE-002 | P1 | Activity state MUST represent connecting, running, tool, waiting, completed, failed, and stopped phases. | Lock Screen/Dynamic Island content follows actual chat state. |
| LIVE-003 | P1 | Tapping the activity MUST deep-link to the associated local conversation. | Existing conversation opens without creating a new one. |
| LIVE-004 | P1 | Human-input states MUST show waiting rather than generic work. | User can tell that app attention is required. |
| LIVE-005 | P1 | Terminal state MUST end/update the activity appropriately. | Completed, failed, stopped, or deleted sessions do not remain indefinitely active. |
| LIVE-006 | P0 | Conversation deletion MUST end its activity. | No dead deep link remains for deleted content. |
| LIVE-007 | P2 | Activity text MUST avoid sensitive prompt/tool details beyond what product/privacy approves for Lock Screen display. | Lock-screen review confirms data minimisation. |
| LIVE-008 | P1 | ActivityKit unavailability/denial MUST not block chat. | Core send/reply continues normally. |

## Phase presentation

| Phase | Headline intent | Timer |
|---|---|---|
| Connecting | Establishing agent connection | Shown |
| Running | Agent working | Shown |
| Tool | Named tool activity where safe | Shown |
| Waiting | User action required | Shown |
| Completed | Reply ready | Hidden |
| Failed | Reply failed | Hidden |
| Stopped | Work stopped | Hidden |

Lock Screen content is visible outside the unlocked app. Avoid exposing file paths, prompt content,
or tool arguments by default.

## App Group requirements

The identifier must match in:

- shared source constant;
- main app entitlement;
- widget entitlement;
- Apple Developer capability;
- provisioning profiles.

An identifier change is a coordinated release/signing task, not an isolated string edit.

## Edge cases

- App has never published a snapshot.
- Snapshot decoding fails after schema evolution.
- Widget link references an agent deleted before tap.
- Conversation is deleted while Live Activity is visible.
- Deep link arrives during a presented scanner or sheet.
- ActivityKit authorization is denied.
- Device does not support Dynamic Island.
- App is terminated while activity is running.
- Lock Screen content would reveal sensitive tool context.
- App Group provisioning is absent in one target.

## Accessibility and privacy

- Widget links need meaningful labels.
- Do not rely only on colour for activity phase.
- Compact Dynamic Island states should use recognisable text/icon combinations.
- Shared snapshot and Lock Screen content follow data minimisation.
- System surfaces must respect selected app identity/display naming without exposing raw addresses
  unnecessarily.

## Source ownership

Primary sources:

- `ConnectOnionShared/ConnectOnionSharedData.swift`
- `ConnectOnionShared/AgentReplyActivityAttributes.swift`
- `ConnectOnionWidget/ConnectOnionWidget.swift`
- `ConnectOnionWidget/ConnectOnionLiveActivity.swift`
- `Core/SystemIntegrations/AgentReplyLiveActivityController.swift`
- `Features/Shell/AppShellView.swift`
- `Config/*.entitlements`
- `Config/ConnectOnion-Info.plist`

Related tests:

- deep-link round-trip/rejection tests;
- widget snapshot encode/decode tests;
- UI navigation coverage for relevant destinations;
- physical-device manual checks for Widget and Live Activity.

## Future considerations

- Universal Links.
- User-configurable widget agent selection.
- App Intents for Shortcuts/Siri.
- Push notification for completed remote work.
- Redacted Lock Screen privacy mode.
- Snapshot versioning.

## Definition of done

A System Integration change is done when app and extension targets compile, App Group/entitlements
are aligned, stale/missing data is safe, navigation validates identifiers, Live Activity terminal
cleanup works, Lock Screen privacy is reviewed, and device validation is recorded.
