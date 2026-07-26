# Settings, Design, and Accessibility Requirements

## Purpose

This document defines user preferences, personalisation behavior, visual-system consistency,
typography/code presentation, motion, and accessibility expectations across the application.

## Scope

- light/dark/system appearance;
- UI font and size;
- code font and syntax highlighting;
- personality mode;
- custom instructions;
- settings navigation and agent details;
- semantic colours and surfaces;
- brand typography and onion animation;
- reduced motion, Dynamic Type, VoiceOver, focus, and identifiers.

## Non-goals

- remote agent profile configuration;
- server-side model personality;
- full localisation strategy;
- analytics/experimentation framework;
- replacing platform accessibility APIs.

## Settings requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| SET-001 | P1 | Appearance MUST support system, light, and dark modes. | Selection applies immediately and persists across launches. |
| SET-002 | P1 | UI font preference MUST apply consistently to app content. | Pushed views and sheets inherit the selected font environment. |
| SET-003 | P1 | UI font size MUST be normalised to safe supported bounds. | Corrupt/out-of-range stored values do not break layout. |
| SET-004 | P1 | Code font selection MUST resolve to a monospaced font. | Every supported preference renders code monospaced. |
| SET-005 | P1 | Syntax highlighting MUST preserve exact source text. | Copying code returns original content. |
| SET-006 | P2 | Unknown explicit code languages MUST fall back to plain rendering. | No failed/highlighter-corrupted output. |
| SET-007 | P1 | Personality and custom instructions MUST persist locally. | New sends use the saved values after relaunch. |
| SET-008 | P0 | Custom instructions MUST remain transport context, not falsely visible user text. | Canonical history sanitisation restores the visible original request. |
| SET-009 | P1 | Custom instructions MUST defer to higher-priority agent/system instructions. | Wrapper copy explicitly communicates precedence. |
| SET-010 | P1 | Agent detail settings MUST distinguish local configuration from remote profile fields. | Editable alias/endpoint are not confused with server-owned capabilities. |
| SET-011 | P2 | Settings sections SHOULD remain understandable without technical protocol knowledge. | Labels explain user impact instead of internal type names. |

## Personalisation contract

The outgoing transmitted prompt may include:

- a versioned opening marker;
- selected personality instruction;
- custom instructions;
- a closing marker;
- a user-request marker;
- the original visible request.

Rules:

1. The same transmitted prompt must be signed and sent.
2. Visible history removes only a complete recognised leading wrapper.
3. Malformed or inline marker-like user text must not be stripped.
4. Recognised leading server system-reminder envelopes may also be removed from visible history.
5. Regenerate uses the latest saved personalisation at regeneration time.
6. Pending onboarding resume preserves the captured original input context.
7. Marker-format changes require compatibility with previously stored/canonical content.

## Design system requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| DSN-001 | P1 | Feature UI SHOULD use semantic application colours rather than duplicated literals. | Appearance changes remain coherent across modules. |
| DSN-002 | P1 | Dark mode SHOULD use the approved warm canvas rather than unintended pure black. | Root and transparent scroll backgrounds remain consistent. |
| DSN-003 | P1 | Interactive cards MUST use consistent hierarchy for title, context, status, and action. | Ask/approval/plan/onboarding cards feel related without becoming indistinguishable. |
| DSN-004 | P1 | Agent/user/assistant content MUST remain visually distinguishable without relying only on colour. | Shape, alignment, labels, or hierarchy provide additional cues. |
| DSN-005 | P2 | Motion SHOULD use shared timing/style primitives. | Launch, onion, press, and reply animations do not introduce arbitrary competing motion. |
| DSN-006 | P1 | Brand assets MUST retain correct aspect and approved colour treatment. | Onion/wordmark is not stretched or recoloured inconsistently. |
| DSN-007 | P1 | Liquid Glass and blur surfaces MUST preserve text contrast. | Content remains legible in both appearances and increased contrast settings. |

## Accessibility requirements

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| A11Y-001 | P0 | Every core action MUST be discoverable and operable with VoiceOver. | Add, send, approve/reject, answer, delete confirmation, and navigation work without gesture-only knowledge. |
| A11Y-002 | P1 | Important status MUST not rely only on colour. | Online/running/waiting/error includes text, icon, shape, or accessibility value. |
| A11Y-003 | P1 | Dynamic Type MUST preserve core actions and readable content. | Large accessibility sizes do not hide send/stop/decision controls. |
| A11Y-004 | P1 | Reduced Motion SHOULD replace or minimise non-essential brand and typewriter animation. | Content remains understandable and promptly available. |
| A11Y-005 | P1 | Interactive controls MUST have meaningful labels, hints, and state values. | VoiceOver announces purpose and selected/pending/resolved state. |
| A11Y-006 | P1 | Focus SHOULD move predictably after navigation, modal dismissal, send, and card resolution. | User is not stranded at removed content. |
| A11Y-007 | P1 | Text/background contrast MUST meet the applicable WCAG/platform expectations. | Light/dark and disabled states pass review. |
| A11Y-008 | P1 | UI automation identifiers MUST be stable and semantic. | Tests do not depend on transient visible copy where a stable identifier exists. |
| A11Y-009 | P2 | Images and decorative brand marks MUST have appropriate labels or be hidden from accessibility. | Decorative layers are not announced repetitively. |
| A11Y-010 | P1 | Keyboard dismissal and focus behavior MUST not block switch/keyboard users. | Forms can be completed without touch-only background gestures. |

## Content and error-writing rules

- Lead with the user-actionable problem.
- Name an endpoint only when it helps the user fix connectivity.
- Avoid blaming “internet” for a LAN/relay/protocol problem.
- Distinguish local alias from remote profile name.
- Distinguish waiting for user input from active agent work.
- Do not present internal wrapper/system-reminder text.
- Avoid exposing raw JSON unless in a deliberate diagnostic surface.
- Destructive actions state what local data is removed.
- Signing/identity reset copy explains continuity impact.

## Edge cases

- Stored font preference is no longer available.
- Code language is unknown.
- Markdown contains malformed fences.
- Custom instruction contains marker-like text.
- Very large Dynamic Type with interactive cards.
- VoiceOver while timeline updates live.
- Reduce Motion enabled during launch/typewriter animation.
- High contrast/dark mode over translucent surfaces.
- Settings change while a reply is streaming.
- User chooses a font that changes line wrapping in long code.

## Source ownership

Primary sources:

- `Features/Settings/SettingsView.swift`
- `Features/Settings/AppearancePicker.swift`
- `Features/Settings/AgentDetailView.swift`
- `Core/Support/PersonalisationPreferences.swift`
- `Core/Support/CustomInstructions.swift`
- `Design/*`
- `Features/Chat/Timeline/MarkdownMessageView.swift`
- `Core/Support/AccessibilityID.swift`

Related tests:

- personalisation preference tests;
- syntax highlighting tests;
- custom-instruction round-trip/sanitisation tests;
- UI tests using stable identifiers;
- manual VoiceOver, Dynamic Type, contrast, and Reduce Motion checks.

## Collaboration requirements

- Design changes include light/dark and large-text evidence.
- New animation includes a reduced-motion behavior.
- New interactive controls include accessibility semantics before review.
- Changes to wrapper markers involve Chat, Protocol, and Persistence reviewers.
- New fonts/assets include licensing and target-membership review.

## Future considerations

- Formal accessibility audit.
- Localisation and pseudolocalisation.
- Per-conversation personalisation override.
- Theme preview and reset-to-default.
- User-controlled Live Activity privacy.
- Automated screenshot/visual regression testing.

## Definition of done

A Settings/Design change is done when persistence, immediate application, wrapper compatibility,
light/dark states, Dynamic Type, VoiceOver, reduced motion, contrast, code-copy fidelity, assets,
licensing, and automated/manual evidence are complete.
