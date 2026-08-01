//
//  ChatViewModel.swift
//
//  Purpose: Implements ChatViewModel for the Features/Chat module.
//  Collaborates with: ChatErrorBanner, ChatHeaderView, ChatItemView, ChatMessageList, ChatScreen, ChatTimeline.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Factory
import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    // Internal rather than private so the split-out extensions (ChatViewModel+LiveActivity) can reach
    // them; the type is still the only owner.
    let agent: AgentConfig
    let conversation: ConversationRecord
    /// Per-conversation so an unanswered card's draft can never surface in a different chat — several
    /// card ids (e.g. the onboarding fallback id) are fixed strings shared across conversations.
    let cardDrafts = CardDraftStore()

    var items: [ChatItem]
    var sessionState: SessionActiveState = .idle {
        didSet {
            guard sessionState != oldValue else { return }
            onSessionStateChange(sessionState)
        }
    }
    var errorMessage: String?
    var elapsedTime: TimeInterval = 0
    /// The model that produced the latest reply, shown as a footer under it. Captured from events (the
    /// server's final `chatItems` may drop the thinking row that carries it).
    var lastResponseModel: String?
    /// The reply currently being typed out client-side, or nil when no typewriter reveal is active.
    var streamingMessageID: ChatItem.ID?
    private(set) var latestTurnCompleted = false

    @ObservationIgnored
    @Injected(\.connectOnionClient) private var injectedClient: ConnectOnionClientProviding

    @ObservationIgnored
    @Injected(\.liveActivityController) var liveActivity: AgentReplyLiveActivityController

    @ObservationIgnored private let clientOverride: ConnectOnionClientProviding?
    @ObservationIgnored private let onSessionStateChange: (SessionActiveState) -> Void
    @ObservationIgnored private let onReplyReady: () -> Void
    @ObservationIgnored private let onReplyCompleted: @MainActor (ConversationRecord) -> Void
    @ObservationIgnored private var onAgentProfile: @MainActor (AgentProfile) -> Void
    @ObservationIgnored private let customInstructionsProvider: @MainActor () -> String
    @ObservationIgnored private let personalityProvider: @MainActor () -> PersonalityMode
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var persistTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var pendingUserItem: ChatItem?
    @ObservationIgnored private var inFlightInput: AgentInput?
    @ObservationIgnored private var inFlightReplacementSessionID: String?
    @ObservationIgnored private var inFlightUserItemID: String?
    @ObservationIgnored private var inFlightWasFirstPrompt = false
    @ObservationIgnored private var optimisticUserItemID: String?
    @ObservationIgnored private var automaticReconnectAttempts = 0
    @ObservationIgnored private var automaticReconnectTask: Task<Void, Never>?
    @ObservationIgnored private var regenerateBackup: RegenerationBackup?
    // While replacing a turn, keep the locally-trimmed view authoritative until the fork completes.
    // This prevents stale canonical data from briefly resurrecting the removed exchange.
    @ObservationIgnored private var isRegenerating = false
    private var deferredOnboardTurn: DeferredOnboardTurn?

    init(
        conversation: ConversationRecord,
        agent: AgentConfig,
        client: ConnectOnionClientProviding? = nil,
        onSessionStateChange: @escaping (SessionActiveState) -> Void = { _ in },
        onReplyReady: @escaping () -> Void = {},
        onReplyCompleted: @escaping @MainActor (ConversationRecord) -> Void = { _ in },
        onAgentProfile: @escaping @MainActor (AgentProfile) -> Void = { _ in },
        customInstructionsProvider: @escaping @MainActor () -> String = { CustomInstructions.saved },
        personalityProvider: @escaping @MainActor () -> PersonalityMode = { PersonalityMode.saved }
    ) {
        self.conversation = conversation
        self.agent = agent
        let restoredItems = conversation.messages
        items = AgentContentSanitizer.sanitize(Self.sanitizingUserPrompts(in: restoredItems))
        clientOverride = client
        self.onSessionStateChange = onSessionStateChange
        self.onReplyReady = onReplyReady
        self.onReplyCompleted = onReplyCompleted
        self.onAgentProfile = onAgentProfile
        self.customInstructionsProvider = customInstructionsProvider
        self.personalityProvider = personalityProvider
        finalizeRunningItems() // restored items must never resume the live "running" animation
        lastResponseModel = items.last { $0.kind == .agent && $0.model?.isEmpty == false }?.model
            ?? items.last { $0.kind == .thinking && $0.model?.isEmpty == false }?.model
        sessionState = items.isEmpty ? .idle : .connected
        latestTurnCompleted = hasCompletedLatestExchange
        if items != restoredItems {
            conversation.messages = items
        }
    }

    /// Any item persisted / left mid-flight as `.running` would keep the peeling-onion animation
    /// spinning forever; settle them to `.done` when a turn ends or on load.
    private func finalizeRunningItems() {
        for index in items.indices where items[index].status == .running {
            items[index].status = .done
        }
    }

    deinit {
        streamTask?.cancel()
        timerTask?.cancel()
        persistTask?.cancel()
        automaticReconnectTask?.cancel()
    }

    var hasOngoingSession: Bool {
        // Pending-action responses intentionally restore the composer to `.connected` while the
        // original receive loop continues, so the task—not the presentation state—is authoritative.
        streamTask != nil
    }

    func send(_ input: AgentInput) {
        send(input.prompt, images: input.images, files: input.files)
    }

    func send(_ prompt: String, images: [String] = [], files: [FileAttachment] = [], isRegenerate: Bool = false) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !files.isEmpty else { return }
        // A conversation has one active turn at a time. Besides matching the server protocol, this
        // closes the tiny window before SwiftUI swaps Send for Stop where a second submit could
        // otherwise cancel and replace the first request.
        guard streamTask == nil else { return }

        let input = AgentInput(
            prompt: trimmed,
            customInstructions: customInstructionsProvider(),
            personality: personalityProvider(),
            images: images,
            files: files
        )
        sendCapturedInput(
            input,
            replacementSessionID: isRegenerate ? UUID().uuidString : nil
        )
    }

    private func sendCapturedInput(
        _ input: AgentInput,
        replacementSessionID: String? = nil,
        reusingUserItemID: ChatItem.ID? = nil
    ) {
        // CONNECT carries the history *before* this input; INPUT carries the new prompt separately.
        // Capture it before appending the optimistic rows or the backend would receive the prompt twice.
        let session = replacementSessionID.map {
            replacementSnapshot(sessionID: $0, excludingUserItemID: reusingUserItemID)
        } ?? snapshot(excludingUserItemID: reusingUserItemID)

        // Starting a turn retires any earlier failure — Retry must never resurrect a stale prompt.
        failedTurn = nil
        failedTurnCanResend = false
        isRegenerating = replacementSessionID != nil
        latestTurnCompleted = false
        errorMessage = nil
        streamingMessageID = nil
        lastResponseModel = nil
        automaticReconnectAttempts = 0
        automaticReconnectTask?.cancel()
        inFlightInput = input
        inFlightReplacementSessionID = replacementSessionID
        var userItem = reusingUserItemID.flatMap { reusedID in
            items.first { $0.id == reusedID && $0.kind == .user }
        } ?? ChatItem(
            id: reusingUserItemID ?? UUID().uuidString,
            kind: .user,
            content: input.prompt
        )
        userItem.content = input.prompt
        userItem.images = input.images
        userItem.files = input.files
        pendingUserItem = userItem
        optimisticUserItemID = userItem.id
        if !items.contains(where: { $0.id == userItem.id }) {
            append(userItem, shouldPersist: false)
        }

        if !items.contains(where: { $0.id == "__optimistic__" }) {
            var placeholder = ChatItem(id: "__optimistic__", kind: .thinking)
            placeholder.status = .running
            append(placeholder, shouldPersist: false)
        }
        if let replacementSessionID {
            // The local transcript has already forked. Persist the fork now so a kill-and-resume
            // re-attaches to the REPLACEMENT session; otherwise reconnect() would rebuild the
            // transcript from the branch we just replaced and resurrect the deleted exchange.
            // Rollback is unaffected — captureRegenerationBackup() snapshots all three fields.
            conversation.remoteSessionID = replacementSessionID
            conversation.rawSession = nil
            conversation.lastRenderedEventID = nil
            pendingRawSession = nil
        }
        // Mark the turn in-flight so a force-kill mid-reply is recoverable: on next open the
        // conversation re-attaches to the still-running server session (see `resumeIfInterrupted`).
        conversation.pendingTurnStartedAt = .now
        didSendInput = false
        // Persist the user turn immediately. The presentation-only thinking placeholder is filtered
        // by persist(), so a connection failure keeps the sent bubble without saving fake activity.
        persist()

        sessionState = .connecting
        elapsedTime = 0
        startTimer()
        liveActivity.start(conversationID: conversation.id, agentAddress: agent.address, agentName: agent.displayName)

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in client.send(input: input, to: agent, session: session) {
                    handle(event)
                }
            } catch is CancellationError {
                return
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    /// The session store survives navigation, so sanitize again whenever the retained chat is shown.
    func prepareForPresentation() {
        sanitizeAllContent()
    }

    /// Clear the typewriter marker once a message finishes revealing (called when streaming completes).
    func markStreamingComplete(_ id: ChatItem.ID) {
        if streamingMessageID == id {
            streamingMessageID = nil
        }
    }

    /// Convenience: regenerate the most recent agent reply (no-op if there is none).
    func regenerate() {
        guard let latest = items.last(where: { $0.kind == .agent })?.id else { return }
        regenerate(replyID: latest)
    }

    /// Re-run the user turn that produced a particular reply. Regenerating an older reply creates a
    /// new branch, so dependent turns after it are removed together with the selected exchange.
    func regenerate(replyID: ChatItem.ID) {
        guard let replyIndex = items.firstIndex(where: { $0.id == replyID && $0.kind == .agent }),
              let userIndex = items[..<replyIndex].lastIndex(where: { $0.kind == .user }) else { return }
        let userItem = items[userIndex]
        captureRegenerationBackup()
        items.removeSubrange(userIndex...)
        persist()
        send(userItem.content, images: userItem.images, files: userItem.files, isRegenerate: true)
    }

    /// Replace only the latest completed user turn, preserving its attachments, then run the same
    /// rollback-safe transaction used by reply regeneration.
    @discardableResult
    func editLatestUserMessage(id: ChatItem.ID, prompt: String) -> Bool {
        guard editableLatestUserMessageID == id,
              let lastUserIndex = items.lastIndex(where: { $0.kind == .user }),
              items[lastUserIndex].id == id else {
            return false
        }

        let userItem = items[lastUserIndex]
        let editedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalPrompt = userItem.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard editedPrompt != originalPrompt,
              !editedPrompt.isEmpty || !userItem.images.isEmpty || !userItem.files.isEmpty else {
            return false
        }

        captureRegenerationBackup()
        items.removeSubrange(lastUserIndex...)
        persist()
        send(editedPrompt, images: userItem.images, files: userItem.files, isRegenerate: true)
        return true
    }

    func reconnect() {
        errorMessage = nil
        sessionState = .reconnecting
        startTimer()
        liveActivity.start(conversationID: conversation.id, agentAddress: agent.address, agentName: agent.displayName)
        liveActivity.update(
            conversationID: conversation.id,
            phase: .connecting,
            headline: "Reconnecting to \(agent.displayName)",
            detail: "Restoring the active conversation"
        )

        streamTask?.cancel()
        let session = inFlightReplacementSessionID.map {
            replacementSnapshot(sessionID: $0)
        } ?? snapshot()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in client.reconnect(to: agent, session: session) {
                    handle(event)
                }
                settleIdleReconnectIfNeeded()
            } catch is CancellationError {
                return
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    /// Beyond this age a persisted in-flight turn is treated as abandoned rather than resumed.
    private static let staleTurnCutoff: TimeInterval = 30 * 60

    /// Sticky across the whole background episode: set if a turn was live when we were suspended, and
    /// only cleared once we have actually attempted the foreground re-attach.
    @ObservationIgnored private var wasSuspendedMidTurn = false
    @ObservationIgnored private var lastResumeAttemptAt: Date?
    @ObservationIgnored private var backgroundedAt: Date?
    /// The turn a terminal failure interrupted, kept so Retry can re-send instead of silently
    /// dropping the user's message.
    @ObservationIgnored private var failedTurn: DeferredOnboardTurn?
    @ObservationIgnored private var failedTurnCanResend = false
    /// True once this turn's INPUT frame left the device. CONNECTED is NOT a safe proxy: the client
    /// yields it before building and sending INPUT, so a failure in between must still be resendable.
    @ObservationIgnored private var didSendInput = false
    /// Latest raw session blob from the event stream, flushed by the debounced `persist()`. Assigning
    /// `conversation.rawSession` directly JSON-encodes the blob and bumps `updatedAt` synchronously,
    /// which during a fast event burst hitches the UI.
    @ObservationIgnored var pendingRawSession: JSONValue?

    /// A backgrounding shorter than this is treated as a peek (Control Center, a glance at another
    /// app): the socket almost certainly survived, so a live turn is left alone rather than re-dialled.
    private static let backgroundGrace: TimeInterval = 5

    /// Record that the app is being suspended while this conversation has work in flight. iOS may kill
    /// or freeze us here and the socket dies silently, so foregrounding must re-attach.
    func noteAppWillEnterBackground() {
        wasSuspendedMidTurn = wasSuspendedMidTurn || streamTask != nil || conversation.pendingTurnStartedAt != nil
        if backgroundedAt == nil { backgroundedAt = .now }
        // Suspension can become termination without warning; get the newest session blob on disk now
        // rather than leaving it in the debounced slot.
        if pendingRawSession != nil { persist() }
    }

    /// Re-attach after returning from the background. Unlike `resumeIfInterrupted`, this deliberately
    /// bypasses the `streamTask == nil` guard: after a suspension the task object often survives while
    /// its socket is already dead, which is exactly the "frozen thinking forever" case.
    func resumeAfterForeground() {
        guard wasSuspendedMidTurn else { return }
        let suspendedFor = backgroundedAt.map { Date.now.timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        backgroundedAt = nil

        // Debounce BEFORE consuming the sticky flag, so a swallowed call (foreground racing a deep
        // link) leaves the record intact for the next attempt instead of losing the resume entirely.
        guard !isResumeDebounced else { return }
        guard conversation.pendingTurnStartedAt != nil else {
            wasSuspendedMidTurn = false
            return
        }

        // A brief peek with a stream still attached: don't tear down a healthy socket.
        if suspendedFor < Self.backgroundGrace, streamTask != nil {
            wasSuspendedMidTurn = false
            return
        }
        wasSuspendedMidTurn = false

        if hasCompletedLatestExchange {
            conversation.pendingTurnStartedAt = nil
            persist()
            return
        }

        if let startedAt = conversation.pendingTurnStartedAt,
           Date.now.timeIntervalSince(startedAt) > Self.staleTurnCutoff {
            expireInterruptedTurn()
            return
        }

        automaticReconnectAttempts = 0
        reconnect() // cancels streamTask and force-dials a fresh connection
    }

    /// Collapses a burst of resume triggers (foreground + a deep link pushing the chat) into one.
    private var isResumeDebounced: Bool {
        if let lastResumeAttemptAt, Date.now.timeIntervalSince(lastResumeAttemptAt) < 2 { return true }
        lastResumeAttemptAt = .now
        return false
    }

    /// Abandon a turn we will not resume. Must also release the stream: `send()` refuses to run while
    /// `streamTask != nil`, so leaving one behind wedges the conversation with no visible Stop button.
    private func expireInterruptedTurn() {
        streamTask?.cancel()
        streamTask = nil
        automaticReconnectTask?.cancel()
        automaticReconnectTask = nil
        client.disconnect()
        conversation.pendingTurnStartedAt = nil
        pendingUserItem = nil
        clearInFlightInput()
        clearOptimisticPlaceholder()
        finalizeRunningItems()
        sessionState = items.isEmpty ? .idle : .connected
        stopTimer()
        persist()
    }

    /// Recovers a turn left in-flight when the app was killed or backgrounded. A force-kill terminates
    /// all in-app work, so the only reliable recovery is server-side: the agent keeps running and, on
    /// next open, we re-attach via `reconnect()` — which sends only CONNECT (session_id + last_msg_id),
    /// never a second INPUT, so the running turn resumes (its events/reply stream back in) rather than
    /// restarting. A no-op when nothing was interrupted, so it is safe to call on every appear.
    func resumeIfInterrupted() {
        guard streamTask == nil else { return }              // a live turn already owns the stream
        guard let startedAt = conversation.pendingTurnStartedAt else { return }
        guard !isResumeDebounced else { return }

        // The reply already arrived locally before the app went away — just clear the marker.
        if hasCompletedLatestExchange {
            conversation.pendingTurnStartedAt = nil
            persist()
            return
        }

        // An abandoned turn: don't re-attach to a session the host has long since dropped.
        if Date.now.timeIntervalSince(startedAt) > Self.staleTurnCutoff {
            expireInterruptedTurn()
            return
        }

        reconnect()
    }

    func respondToAskUser(_ answer: String) {
        ChatEventReducer.markLatestAskUserAnswered(answer: answer, in: &items)
        persist()
        // Answering a card hands control back to the user (composer returns to send). If the agent
        // resumes on the live stream, the incoming events flip sessionState back to .active.
        sessionState = .connected
        updateLiveActivityAfterUserAction("Continuing after your answer")

        Task {
            do {
                try await client.sendAskUserResponse(answer)
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func respondToApproval(approved: Bool, scope: String, mode: String? = nil, feedback: String? = nil) {
        ChatEventReducer.markLatestApprovalAnswered(approved: approved, scope: scope, mode: mode, in: &items)
        persist()
        sessionState = .connected
        updateLiveActivityAfterUserAction(approved ? "Approval sent" : "Skipped the tool call")
        Task {
            do {
                try await client.sendApprovalResponse(approved: approved, scope: scope, mode: mode, feedback: feedback)
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func submitOnboard(inviteCode: String?, payment: Double? = nil) {
        ChatEventReducer.markLatestOnboardSubmitted(inviteCode: inviteCode, payment: payment, in: &items)
        persist()
        sessionState = .connected
        updateLiveActivityAfterUserAction("Verification submitted")
        Task {
            do {
                try await client.sendOnboardSubmit(inviteCode: inviteCode, payment: payment)
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func respondToPlanReview(_ message: String) {
        ChatEventReducer.markLatestPlanReviewAnswered(message: message, in: &items)
        persist()
        sessionState = .connected
        updateLiveActivityAfterUserAction("Plan feedback sent")
        Task {
            do {
                try await client.sendPlanReviewResponse(message)
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        automaticReconnectTask?.cancel()
        automaticReconnectTask = nil
        client.disconnect()
        pendingUserItem = nil
        clearInFlightInput()
        deferredOnboardTurn = nil
        failedTurn = nil // the user cancelled deliberately
        let restoredRegeneration = restoreRegenerateBackup()
        latestTurnCompleted = false
        if !restoredRegeneration {
            commitOptimisticUserPrompt()
            clearOptimisticPlaceholder()
            finalizeRunningItems() // stop the peeling-onion animation on any half-finished item
            persist()
        }
        stopTimer()
        conversation.pendingTurnStartedAt = nil // user cancelled — turn no longer awaiting a reply
        sessionState = items.isEmpty ? .idle : .connected
        persist()
        liveActivity.end(
            conversationID: conversation.id,
            phase: .stopped,
            headline: "Agent stopped",
            detail: "The current reply was cancelled"
        )
    }

    private var client: ConnectOnionClientProviding {
        clientOverride ?? injectedClient
    }

    func setAgentProfileHandler(_ handler: @escaping @MainActor (AgentProfile) -> Void) {
        onAgentProfile = handler
    }

    private func handle(_ event: ConnectOnionClientEvent) {
        switch event {
        case .inputSent:
            didSendInput = true

        case .connected(let sessionID, let status, let serverNewer, let session, let chatItems):
            conversation.remoteSessionID = sessionID.isEmpty ? conversation.remoteSessionID : sessionID
            if serverNewer, !isRegenerating {
                conversation.rawSession = session
                pendingRawSession = nil
                ChatEventReducer.reconcile(
                    with: AgentContentSanitizer.sanitize(Self.sanitizingUserPrompts(in: chatItems)),
                    items: &items
                )
                persist()
            }

            if let pendingUserItem {
                // The user row is already visible. Determine whether it was the first prompt by
                // excluding that optimistic row, but only mark it after CONNECTED. Some hosts send
                // ONBOARD_REQUIRED before CONNECTED and continue the same input after verification;
                // treating that pre-connect gate as a post-connect deferral would resend it twice.
                let wasFirstPrompt = !items.contains {
                    $0.kind == .user && $0.id != pendingUserItem.id
                }
                optimisticUserItemID = pendingUserItem.id
                inFlightUserItemID = pendingUserItem.id
                inFlightWasFirstPrompt = wasFirstPrompt
                if !items.contains(where: { $0.id == pendingUserItem.id }) {
                    append(pendingUserItem, shouldPersist: false)
                }

                if !items.contains(where: { $0.id == "__optimistic__" }) {
                    var placeholder = ChatItem(id: "__optimistic__", kind: .thinking)
                    placeholder.status = .running
                    append(placeholder, shouldPersist: false)
                }

                self.pendingUserItem = nil
                sessionState = .active
                if startedAt == nil {
                    startTimer()
                }
                liveActivity.update(
                    conversationID: conversation.id,
                    phase: .running,
                    headline: "\(agent.displayName) is working",
                    detail: "Waiting for the first streamed event"
                )
            } else {
                sessionState = status == "running" ? .active : .connected
            }
            errorMessage = nil

        case .profile(let profile):
            onAgentProfile(profile)

        case .control(let event):
            // Passive protocol state must never acknowledge the optimistic turn or remove its
            // activity placeholder. connectonion emits session_sync after every trace event and can
            // change approval mode independently of a reply.
            if let session = event.payload["session"] {
                pendingRawSession = session
            }
            if event.type == "mode_changed",
               let rawMode = event.payload[string: "mode"],
               let mode = ApprovalMode(rawValue: rawMode) {
                conversation.mode = mode
            }
            schedulePersist()

        case .server(let event):
            let previousAgentID = items.last(where: { $0.kind == .agent })?.id
            #if DEBUG
            // Surface the exact wire type of any verification/invite event so an unhandled rejection
            // name (not in ChatEventReducer's candidate set) can be identified from one repro.
            if event.type.range(of: "ONBOARD", options: .caseInsensitive) != nil
                || event.type.range(of: "VERIF", options: .caseInsensitive) != nil
                || event.type.range(of: "INVITE", options: .caseInsensitive) != nil {
                print("🔎 [onboard] server event type=\(event.type) payload=\(event.payload)")
            }
            #endif
            if event.type == "ONBOARD_REQUIRED", inFlightWasFirstPrompt {
                if let inFlightInput {
                    deferredOnboardTurn = DeferredOnboardTurn(
                        input: inFlightInput,
                        replacementSessionID: inFlightReplacementSessionID,
                        userItemID: inFlightUserItemID ?? optimisticUserItemID
                    )
                }
                // The host may require verification after acknowledging the first input. Keep the
                // already-sent user bubble visible and reuse it when the input is replayed.
                clearInFlightInput()
            } else {
                commitOptimisticUserPrompt()
            }
            clearOptimisticPlaceholder()
            if let newState = ChatEventReducer.apply(event, to: &items) {
                sessionState = newState
                if newState == .waiting {
                    onReplyReady()
                }
            }
            sanitizeItemsAffected(by: event)
            // A fresh assistant reply arrived via the reducer (the usual path for a real agent) — type
            // it out client-side. A merged/incremental update keeps the same id, so it won't retrigger.
            if event.type == "assistant",
               let lastAgent = items.last(where: { $0.kind == .agent }),
               lastAgent.id != previousAgentID {
                streamingMessageID = lastAgent.id
            }
            if (event.type == "llm_call" || event.type == "llm_result"),
               let model = event.payload[string: "model"],
               !model.isEmpty {
                lastResponseModel = model
            }
            updateLiveActivity(for: event)
            if let eventID = event.id {
                conversation.lastRenderedEventID = eventID
            }
            if let session = event.payload["session"] {
                // Hold it in memory; the setter JSON-encodes the whole blob and bumps updatedAt, which
                // is far too expensive to run once per streamed event. persist() flushes it.
                pendingRawSession = session
            }
            if event.type == "mode_changed", let rawMode = event.payload[string: "mode"], let mode = ApprovalMode(rawValue: rawMode) {
                conversation.mode = mode
            }
            schedulePersist()
            if event.type == "ONBOARD_SUCCESS" {
                resumeDeferredOnboardInput()
            }

        case .output(let result, let durationMS, let serverNewer, let session, let chatItems):
            // Capture turn-scoped metrics before a newer canonical snapshot can omit intermediate
            // events. They are persisted on the final reply below.
            let completedTurnDurationMS = currentTurnDurationMS
            let completedContextPercent = contextPercent
            automaticReconnectAttempts = 0
            automaticReconnectTask?.cancel()
            let regenerating = isRegenerating
            let sanitizedChatItems = chatItems.isEmpty ? [] : Self.sanitizingUserPrompts(in: chatItems)
            let replacementResult = regenerating
                ? usableReplacementResult(result: result, chatItems: sanitizedChatItems)
                : result
            commitOptimisticUserPrompt()
            clearInFlightInput()
            clearOptimisticPlaceholder()
            failedTurn = nil // the turn landed; nothing left to retry

            guard !regenerating || replacementResult != nil else {
                streamTask = nil
                conversation.pendingTurnStartedAt = nil // terminal, like every other turn-ending path
                _ = restoreRegenerateBackup()
                errorMessage = "The agent returned an empty response. The original exchange was restored."
                sessionState = items.isEmpty ? .idle : .connected
                stopTimer()
                client.disconnect()
                liveActivity.end(
                    conversationID: conversation.id,
                    phase: .failed,
                    headline: "Reply could not be replaced",
                    detail: "The original exchange was restored"
                )
                return
            }

            regenerateBackup = nil // a usable replacement exists, so the old exchange is no longer needed
            isRegenerating = false
            let finalResult = AgentContentSanitizer.sanitize(replacementResult ?? result)
            // Only adopt a newer server snapshot, and reconcile it at a user-turn boundary so an
            // unacknowledged local turn and locally answered cards cannot be rolled back.
            if serverNewer, !regenerating {
                // Use the prompt-stripped list (as restore + the .connected path do), otherwise the
                // host-echoed personalisation/custom-instructions wrapper leaks into visible user
                // bubbles because reconcile matches user items by content and never finds the local one.
                ChatEventReducer.reconcile(with: AgentContentSanitizer.sanitize(sanitizedChatItems), items: &items)
            }
            // Ensure the fresh reply exists as the LAST item so it can be revealed. Guard on the last
            // *item* (not the last agent anywhere): on a regenerate the canonical list is skipped, so a
            // prior turn's identical reply must not be mistaken for this turn's — there the re-sent user
            // is the last item, so we still append the fresh bubble below it.
            if !finalResult.isEmpty, !(items.last?.kind == .agent && items.last?.content == finalResult) {
                // A streamed agent_image arrives before the reply text and parks in a content-less
                // agent row. Fill that row rather than appending a second bubble: otherwise the turn
                // renders two agent messages, the image-only one is not the turn's final answer, and it
                // would be folded into the collapsed trace (which draws no images) and disappear.
                if let index = items.indices.last,
                   items[index].kind == .agent,
                   items[index].content.isEmpty,
                   !items[index].images.isEmpty {
                    items[index].content = finalResult
                } else {
                    let agentItem = ChatItem(kind: .agent, content: finalResult)
                    append(agentItem, shouldPersist: false)
                }
            }
            finalizeRunningItems()
            // Type the reply out client-side. The host server never emits a live "assistant" event — the
            // reply only ever arrives here in OUTPUT — so point the typewriter at the just-finished reply
            // however it landed (adopted from the canonical list or appended above). This is the single
            // place the reveal is triggered for a normal turn. Skip the reveal for replies with block
            // markdown (code fences, tables, headings): the inline typewriter would show raw ``` / | and
            // then snap to a formatted card — for a coding agent that's most replies, so render formatted
            // immediately instead.
            if !finalResult.isEmpty,
               !Self.hasBlockMarkdown(finalResult),
               let index = items.lastIndex(where: { $0.kind == .agent }),
               items[index].content == finalResult {
                streamingMessageID = items[index].id
            }
            // Stamp the model onto the reply itself so the footer survives a reload — the thinking row
            // that carries it may not be present in the server's canonical list.
            if let model = lastResponseModel,
               let index = items.lastIndex(where: { $0.kind == .agent }) {
                items[index].model = model
            }
            if let index = items.lastIndex(where: { $0.kind == .agent }) {
                items[index].durationMS = durationMS
                    ?? completedTurnDurationMS
                    ?? currentTurnDurationMS
                    ?? items[index].durationMS
                items[index].contextPercent = completedContextPercent
                    ?? contextPercent
                    ?? items[index].contextPercent
            }
            lastResponseModel = items.last(where: { $0.kind == .agent })?.model
            conversation.rawSession = session
            pendingRawSession = nil
            sessionState = .connected
            streamTask = nil
            latestTurnCompleted = hasCompletedLatestExchange
            conversation.pendingTurnStartedAt = nil // reply delivered — turn no longer awaiting
            stopTimer()
            persist()
            onReplyReady()
            client.disconnect()
            liveActivity.complete(
                conversationID: conversation.id,
                headline: "Reply ready",
                detail: "\(agent.displayName) finished responding"
            )
            if !finalResult.isEmpty {
                onReplyCompleted(conversation)
            }

        case .failure(let message):
            fail(message)
        }
    }

    private func append(_ item: ChatItem, shouldPersist: Bool = true) {
        items.append(item)

        if shouldPersist {
            persist()
        }
    }

    private func clearOptimisticPlaceholder() {
        guard let index = items.firstIndex(where: { $0.id == "__optimistic__" }) else { return }
        let id = items[index].id
        items.removeAll { $0.id == id }
    }

    private func commitOptimisticUserPrompt() {
        optimisticUserItemID = nil
    }

    private func clearInFlightInput() {
        inFlightInput = nil
        inFlightReplacementSessionID = nil
        inFlightUserItemID = nil
        inFlightWasFirstPrompt = false
    }

    /// The error banner's action. Re-sends the prompt when it provably never reached the host,
    /// otherwise re-attaches to the session the host is already running.
    func retryLastTurn() {
        guard streamTask == nil else { return } // a retry is already in flight
        guard let turn = failedTurn, failedTurnCanResend else {
            reconnect()
            return
        }
        failedTurn = nil
        errorMessage = nil
        sendCapturedInput(
            turn.input,
            replacementSessionID: turn.replacementSessionID,
            reusingUserItemID: turn.userItemID
        )
    }

    private func resumeDeferredOnboardInput() {
        guard let turn = deferredOnboardTurn else { return }
        deferredOnboardTurn = nil
        Task { @MainActor [weak self] in
            self?.sendCapturedInput(
                turn.input,
                replacementSessionID: turn.replacementSessionID,
                reusingUserItemID: turn.userItemID
            )
        }
    }

    private func captureRegenerationBackup() {
        regenerateBackup = RegenerationBackup(
            items: items,
            remoteSessionID: conversation.remoteSessionID,
            rawSession: pendingRawSession ?? conversation.rawSession,
            lastRenderedEventID: conversation.lastRenderedEventID
        )
    }

    private func persist() {
        persistTask?.cancel()
        persistTask = nil
        if let pendingRawSession {
            conversation.rawSession = pendingRawSession
            self.pendingRawSession = nil
        }
        conversation.messages = items.filter { $0.id != "__optimistic__" }
    }

    /// Stream bursts can contain many tool/LLM events in a few milliseconds. Persist their latest
    /// state once after the burst instead of JSON-encoding the full transcript for every event.
    private func schedulePersist() {
        persistTask?.cancel()
        persistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func sanitizeAllContent() {
        let sanitizedItems = AgentContentSanitizer.sanitize(items)
        guard sanitizedItems != items else { return }
        items = sanitizedItems
        persist()
    }

    /// The reducer normally touches one event id. Sanitize only those rows so a long transcript is
    /// not rescanned for every streamed event; nil-id events fall back to the newly appended tail.
    private func sanitizeItemsAffected(by event: ServerEvent) {
        var indices: [Int] = []
        if let eventID = event.id {
            indices = items.indices.filter { items[$0].id == eventID }
        }
        if indices.isEmpty, let lastIndex = items.indices.last {
            indices = [lastIndex]
        }

        for index in indices.reversed() {
            guard items.indices.contains(index) else { continue }
            if let sanitizedItem = AgentContentSanitizer.sanitize(items[index]) {
                items[index] = sanitizedItem
            } else {
                items.remove(at: index)
            }
        }
    }

    private func fail(_ message: String) {
        if shouldAutomaticallyReconnect(after: message) {
            beginAutomaticReconnect()
            return
        }

        // Terminal failure (not an auto-reconnect): the turn is no longer awaiting a reply.
        conversation.pendingTurnStartedAt = nil
        client.disconnect()
        automaticReconnectTask?.cancel()
        streamTask = nil
        pendingUserItem = nil
        // Remember the turn so Retry can actually re-send it. Resending is only provably safe when no
        // CONNECTED ever arrived — past that point the host may already hold the INPUT, and a second
        // one would duplicate the turn; there Retry just re-attaches.
        if let inFlightInput {
            failedTurn = DeferredOnboardTurn(
                input: inFlightInput,
                replacementSessionID: inFlightReplacementSessionID,
                userItemID: inFlightUserItemID ?? optimisticUserItemID
            )
            failedTurnCanResend = !didSendInput
        }
        clearInFlightInput()
        deferredOnboardTurn = nil

        // A failed regenerate: restore the exchange we optimistically removed rather than losing it.
        if restoreRegenerateBackup() {
            // The original exchange (including its user bubble) is back, so a resend would duplicate it.
            failedTurn = nil
            errorMessage = userFacingError(message)
            sessionState = items.isEmpty ? .idle : .connected
            stopTimer()
            return
        }

        isRegenerating = false
        latestTurnCompleted = false
        commitOptimisticUserPrompt()
        clearOptimisticPlaceholder()
        finalizeRunningItems()
        restoreResponseModelFromHistory()
        errorMessage = userFacingError(message)
        sessionState = .disconnected
        stopTimer()
        persist()
        liveActivity.end(
            conversationID: conversation.id,
            phase: .failed,
            headline: "Agent disconnected",
            detail: errorMessage ?? "The reply could not be completed"
        )
    }

    /// connectonion 1.5.3 deliberately sends no OUTPUT when reconnecting to a session that is
    /// already idle. Release the retained task after the CONNECTED/profile/control sequence so the
    /// composer can accept another message instead of remaining silently blocked.
    private func settleIdleReconnectIfNeeded() {
        guard streamTask != nil else { return }

        // The server had nothing more to stream — the turn is settled; clear the in-flight marker.
        conversation.pendingTurnStartedAt = nil
        streamTask = nil
        automaticReconnectAttempts = 0
        automaticReconnectTask?.cancel()
        automaticReconnectTask = nil
        pendingUserItem = nil
        clearInFlightInput()
        deferredOnboardTurn = nil

        if !restoreRegenerateBackup() {
            isRegenerating = false
            commitOptimisticUserPrompt()
            clearOptimisticPlaceholder()
            finalizeRunningItems()
            latestTurnCompleted = hasCompletedLatestExchange
            persist()
        }

        // A reconnect that finds the session idle is NOT proof the turn was delivered. If a message is
        // still awaiting a reply, keep an actionable banner instead of reporting a clean restore.
        if failedTurn != nil, !hasCompletedLatestExchange {
            // Only promise a resend when one is actually possible; otherwise the host already has the
            // turn and Retry can only re-attach.
            errorMessage = failedTurnCanResend
                ? "Your message wasn't delivered. Tap Retry to send it again."
                : "Reconnected, but the agent produced no reply for your last message."
        } else {
            errorMessage = nil
            failedTurn = nil
        }
        sessionState = items.isEmpty ? .idle : .connected
        stopTimer()
        client.disconnect()
        liveActivity.end(
            conversationID: conversation.id,
            phase: .stopped,
            headline: "Session restored",
            detail: "The agent is ready for another message"
        )
    }

    /// Restores the original exchange when a regenerate is cancelled or fails after partial events.
    /// The snapshot is cleared only by a successful OUTPUT or by this rollback.
    @discardableResult
    private func restoreRegenerateBackup() -> Bool {
        guard let backup = regenerateBackup else { return false }
        regenerateBackup = nil
        isRegenerating = false
        optimisticUserItemID = nil
        streamingMessageID = nil
        items = backup.items
        conversation.remoteSessionID = backup.remoteSessionID
        conversation.rawSession = backup.rawSession
        pendingRawSession = nil
        conversation.lastRenderedEventID = backup.lastRenderedEventID
        finalizeRunningItems()
        latestTurnCompleted = hasCompletedLatestExchange
        restoreResponseModelFromHistory()
        persist()
        return true
    }

    private func restoreResponseModelFromHistory() {
        lastResponseModel = items.last { $0.kind == .agent && $0.model?.isEmpty == false }?.model
            ?? items.last { $0.kind == .thinking && $0.model?.isEmpty == false }?.model
    }

    private var hasCompletedLatestExchange: Bool {
        guard let lastUserIndex = items.lastIndex(where: { $0.kind == .user }),
              let lastAgentIndex = items.lastIndex(where: { $0.kind == .agent }) else {
            return false
        }
        return lastAgentIndex > lastUserIndex
    }

    private func shouldAutomaticallyReconnect(after message: String) -> Bool {
        guard automaticReconnectAttempts == 0 else { return false }
        guard conversation.remoteSessionID != nil else { return false }
        // Previously gated on `hasInFlightAttachments`, so a dropped socket on an ordinary text turn
        // went straight to a terminal failure. Any turn the host is still holding deserves the retry.
        guard conversation.pendingTurnStartedAt != nil, !hasCompletedLatestExchange else { return false }
        switch sessionState {
        case .connecting, .active, .reconnecting:
            return true
        default:
            return false
        }
    }

    private func beginAutomaticReconnect() {
        automaticReconnectAttempts += 1
        errorMessage = nil
        pendingUserItem = nil
        commitOptimisticUserPrompt()
        clearOptimisticPlaceholder()
        stopTimer()
        sessionState = .reconnecting
        liveActivity.update(
            conversationID: conversation.id,
            phase: .connecting,
            headline: "Recovering the reply",
            detail: "Restoring the latest response from \(agent.displayName)"
        )

        automaticReconnectTask?.cancel()
        automaticReconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }
            reconnect()
        }
    }

    private func startTimer() {
        startedAt = .now
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let startedAt else { return }
                elapsedTime = Date.now.timeIntervalSince(startedAt)
            }
        }
    }

    private func stopTimer() {
        startedAt = nil
        timerTask?.cancel()
        timerTask = nil
    }
}
