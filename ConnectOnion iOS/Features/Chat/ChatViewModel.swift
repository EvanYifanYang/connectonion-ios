import Factory
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    private struct RegenerationBackup {
        let items: [ChatItem]
        let remoteSessionID: String?
        let rawSession: JSONValue?
        let lastRenderedEventID: String?
    }

    private struct DeferredOnboardTurn {
        let input: AgentInput
        let replacementSessionID: String?
    }

    private let agent: AgentConfig
    private let conversation: ConversationRecord

    var items: [ChatItem]
    var sessionState: SessionActiveState = .idle
    var errorMessage: String?
    var elapsedTime: TimeInterval = 0
    /// The freshly-arrived agent message that should type itself out (client-side reveal). Cleared once
    /// the bubble finishes revealing. Nil for restored/older messages, so they render in full.
    var streamingMessageID: ChatItem.ID?
    /// The model that produced the latest reply, shown as a footer under it. Captured from events (the
    /// server's final `chatItems` may drop the thinking row that carries it).
    var lastResponseModel: String?
    private(set) var latestTurnCompleted = false

    @ObservationIgnored
    @Injected(\.connectOnionClient) private var injectedClient: ConnectOnionClientProviding

    @ObservationIgnored
    @Injected(\.liveActivityController) private var liveActivity: AgentReplyLiveActivityController

    @ObservationIgnored private let clientOverride: ConnectOnionClientProviding?
    @ObservationIgnored private let customInstructionsProvider: @MainActor () -> String
    @ObservationIgnored private let personalityProvider: @MainActor () -> PersonalityMode
    @ObservationIgnored private let onReplyCompleted: @MainActor (ConversationRecord) -> Void
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
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
        customInstructionsProvider: @escaping @MainActor () -> String = { CustomInstructions.saved },
        personalityProvider: @escaping @MainActor () -> PersonalityMode = { PersonalityMode.saved },
        onReplyCompleted: @escaping @MainActor (ConversationRecord) -> Void = { _ in }
    ) {
        self.conversation = conversation
        self.agent = agent
        items = conversation.messages
        clientOverride = client
        self.customInstructionsProvider = customInstructionsProvider
        self.personalityProvider = personalityProvider
        self.onReplyCompleted = onReplyCompleted
        finalizeRunningItems() // restored items must never resume the live "running" animation
        lastResponseModel = items.last { $0.kind == .agent && $0.model?.isEmpty == false }?.model
            ?? items.last { $0.kind == .thinking && $0.model?.isEmpty == false }?.model
        sessionState = items.isEmpty ? .idle : .connected
        latestTurnCompleted = hasCompletedLatestExchange
    }

    /// Any item persisted / left mid-flight as `.running` would keep the peeling-onion animation
    /// spinning forever; settle them to `.done` when a turn ends or on load.
    private func finalizeRunningItems() {
        for index in items.indices where items[index].status == .running {
            items[index].status = .done
        }
    }

    var pendingAskUser: ChatItem? {
        items.last { $0.kind == .askUser && !$0.answered }
    }

    var pendingApproval: ChatItem? {
        items.last { $0.kind == .approvalNeeded && !$0.answered }
    }

    var pendingOnboard: ChatItem? {
        guard !items.contains(where: { $0.kind == .onboardSuccess }) else { return nil }
        return items.last { $0.kind == .onboardRequired && !$0.answered }
    }

    var pendingPlanReview: ChatItem? {
        items.last { $0.kind == .planReview && !$0.answered }
    }

    var hasPendingUserAction: Bool {
        pendingAskUser != nil ||
            pendingApproval != nil ||
            pendingOnboard != nil ||
            pendingPlanReview != nil
    }

    var shouldShowStopButton: Bool {
        (sessionState == .active || sessionState == .reconnecting) && !hasPendingUserAction
    }

    var isGeneratingReply: Bool {
        switch sessionState {
        case .connecting, .active, .reconnecting:
            true
        default:
            false
        }
    }

    var hasOngoingSession: Bool {
        // Pending-action responses intentionally restore the composer to `.connected` while the
        // original receive loop continues, so the task—not the presentation state—is authoritative.
        streamTask != nil
    }

    var editableLatestUserMessageID: ChatItem.ID? {
        guard latestTurnCompleted,
              sessionState == .connected,
              !hasOngoingSession,
              !hasPendingUserAction,
              errorMessage == nil,
              let lastUserIndex = items.lastIndex(where: { $0.kind == .user }),
              let lastAgentIndex = items.lastIndex(where: { $0.kind == .agent }),
              lastAgentIndex > lastUserIndex else {
            return nil
        }
        return items[lastUserIndex].id
    }

    func send(_ input: AgentInput) {
        send(input.prompt, images: input.images, files: input.files)
    }

    func send(_ prompt: String, images: [String] = [], files: [FileAttachment] = [], isRegenerate: Bool = false) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !files.isEmpty else { return }

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

    private func sendCapturedInput(_ input: AgentInput, replacementSessionID: String? = nil) {
        isRegenerating = replacementSessionID != nil
        latestTurnCompleted = false
        errorMessage = nil
        streamingMessageID = nil
        lastResponseModel = nil
        automaticReconnectAttempts = 0
        automaticReconnectTask?.cancel()
        inFlightInput = input
        inFlightReplacementSessionID = replacementSessionID
        var userItem = ChatItem(kind: .user, content: input.prompt)
        userItem.images = input.images
        userItem.files = input.files
        pendingUserItem = userItem
        sessionState = .connecting
        elapsedTime = 0
        stopTimer()
        liveActivity.start(conversationID: conversation.id, agentAddress: agent.address, agentName: agent.displayName)

        streamTask?.cancel()
        let session = replacementSessionID.map(replacementSnapshot(sessionID:)) ?? snapshot()
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

    /// Called by the agent bubble once its typewriter reveal finishes, so it renders in full and the
    /// action row appears.
    func markStreamingComplete(_ id: ChatItem.ID) {
        if streamingMessageID == id {
            streamingMessageID = nil
        }
    }

    /// Re-run the most recent user turn: drop it and its reply, then send the same input again so a
    /// fresh response streams in its place (no duplicate user bubble). `send` already cancels any
    /// in-flight stream.
    func regenerate() {
        guard let lastUserIndex = items.lastIndex(where: { $0.kind == .user }) else { return }
        let userItem = items[lastUserIndex]
        captureRegenerationBackup()
        items.removeSubrange(lastUserIndex...)
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
        let session = inFlightReplacementSessionID.map(replacementSnapshot(sessionID:)) ?? snapshot()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in client.reconnect(to: agent, session: session) {
                    handle(event)
                }
            } catch is CancellationError {
                return
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    func respondToAskUser(_ answer: String) {
        ChatEventReducer.markLatestAskUserAnswered(answer: answer, in: &items)
        persist()
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
        withAnimation(.smooth(duration: 0.2)) {
            ChatEventReducer.markLatestApprovalAnswered(approved: approved, scope: scope, mode: mode, in: &items)
        }
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
        withAnimation(.smooth(duration: 0.2)) {
            ChatEventReducer.markLatestOnboardSubmitted(inviteCode: inviteCode, payment: payment, in: &items)
        }
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
        withAnimation(.smooth(duration: 0.2)) {
            ChatEventReducer.markLatestPlanReviewAnswered(message: message, in: &items)
        }
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
        let restoredRegeneration = restoreRegenerateBackup()
        latestTurnCompleted = false
        if !restoredRegeneration {
            finalizeRunningItems() // stop the peeling-onion animation on any half-finished item
            persist()
        }
        stopTimer()
        sessionState = items.isEmpty ? .idle : .connected
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

    private func handle(_ event: ConnectOnionClientEvent) {
        switch event {
        case .connected(let sessionID, let status, _, let session, let chatItems):
            conversation.remoteSessionID = sessionID.isEmpty ? conversation.remoteSessionID : sessionID
            conversation.rawSession = session
            if !chatItems.isEmpty, !isRegenerating {
                items = sanitizingUserPrompts(in: chatItems)
                persist()
            }

            if let pendingUserItem {
                let wasFirstPrompt = !items.contains { $0.kind == .user }
                optimisticUserItemID = pendingUserItem.id
                inFlightUserItemID = pendingUserItem.id
                inFlightWasFirstPrompt = wasFirstPrompt
                append(pendingUserItem, animated: true, shouldPersist: false)

                var placeholder = ChatItem(id: "__optimistic__", kind: .thinking)
                placeholder.status = .running
                append(placeholder, animated: true, shouldPersist: false)

                self.pendingUserItem = nil
                sessionState = .active
                startTimer()
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

        case .server(let event):
            let previousAgentID = items.last(where: { $0.kind == .agent })?.id
            if event.type == "ONBOARD_REQUIRED", inFlightWasFirstPrompt {
                if let inFlightInput {
                    deferredOnboardTurn = DeferredOnboardTurn(
                        input: inFlightInput,
                        replacementSessionID: inFlightReplacementSessionID
                    )
                }
                discardInFlightUserPrompt()
            } else {
                commitOptimisticUserPrompt()
            }
            clearOptimisticPlaceholder()
            if let newState = ChatEventReducer.apply(event, to: &items) {
                sessionState = newState
            }
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
                conversation.rawSession = session
            }
            if event.type == "mode_changed", let rawMode = event.payload[string: "mode"], let mode = ApprovalMode(rawValue: rawMode) {
                conversation.mode = mode
            }
            persist()
            if event.type == "ONBOARD_SUCCESS" {
                resumeDeferredOnboardInput()
            }

        case .output(let result, let session, let chatItems):
            automaticReconnectAttempts = 0
            automaticReconnectTask?.cancel()
            regenerateBackup = nil // the resend produced a reply, so drop the restore snapshot
            commitOptimisticUserPrompt()
            clearInFlightInput()
            clearOptimisticPlaceholder()
            let regenerating = isRegenerating
            isRegenerating = false
            // Keep our locally-built replacement view so stale canonical data cannot resurrect the
            // removed exchange or append the revision as a duplicate turn.
            if !chatItems.isEmpty, !regenerating {
                items = sanitizingUserPrompts(in: chatItems)
            }
            // Ensure the fresh reply exists as the LAST item so it can be revealed. Guard on the last
            // *item* (not the last agent anywhere): on a regenerate the canonical list is skipped, so a
            // prior turn's identical reply must not be mistaken for this turn's — there the re-sent user
            // is the last item, so we still append the fresh bubble below it.
            if !result.isEmpty, !(items.last?.kind == .agent && items.last?.content == result) {
                let agentItem = ChatItem(kind: .agent, content: result)
                append(agentItem, animated: true, shouldPersist: false)
            }
            finalizeRunningItems()
            // Type the reply out client-side. The host server never emits a live "assistant" event — the
            // reply only ever arrives here in OUTPUT — so point the typewriter at the just-finished reply
            // however it landed (adopted from the canonical list or appended above). This is the single
            // place the reveal is triggered for a normal turn.
            if !result.isEmpty,
               let index = items.lastIndex(where: { $0.kind == .agent }),
               items[index].content == result {
                streamingMessageID = items[index].id
            }
            // Stamp the model onto the reply itself so the footer survives a reload — the thinking row
            // that carries it may not be present in the server's canonical list.
            if let model = lastResponseModel,
               let index = items.lastIndex(where: { $0.kind == .agent }) {
                items[index].model = model
            }
            lastResponseModel = items.last(where: { $0.kind == .agent })?.model
            conversation.rawSession = session
            sessionState = .connected
            streamTask = nil
            latestTurnCompleted = hasCompletedLatestExchange
            stopTimer()
            persist()
            client.disconnect()
            liveActivity.complete(
                conversationID: conversation.id,
                headline: "Reply ready",
                detail: "\(agent.displayName) finished responding"
            )
            if !result.isEmpty {
                onReplyCompleted(conversation)
            }

        case .failure(let message):
            fail(message)
        }
    }

    private func append(_ item: ChatItem, animated: Bool, shouldPersist: Bool = true) {
        if animated {
            withAnimation(.smooth(duration: 0.24)) {
                items.append(item)
            }
        } else {
            items.append(item)
        }

        if shouldPersist {
            persist()
        }
    }

    private func clearOptimisticPlaceholder() {
        guard let index = items.firstIndex(where: { $0.id == "__optimistic__" }) else { return }
        let id = items[index].id
        withAnimation(.smooth(duration: 0.2)) {
            items.removeAll { $0.id == id }
        }
    }

    private func discardInFlightUserPrompt() {
        let userItemID = inFlightUserItemID ?? optimisticUserItemID
        if let userItemID {
            withAnimation(.smooth(duration: 0.2)) {
                items.removeAll { $0.id == userItemID }
            }
        }
        clearInFlightInput()
        self.optimisticUserItemID = nil
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

    private func resumeDeferredOnboardInput() {
        guard let turn = deferredOnboardTurn else { return }
        deferredOnboardTurn = nil
        Task { @MainActor [weak self] in
            self?.sendCapturedInput(
                turn.input,
                replacementSessionID: turn.replacementSessionID
            )
        }
    }

    private func sanitizingUserPrompts(in chatItems: [ChatItem]) -> [ChatItem] {
        chatItems.map { item in
            guard item.kind == .user else { return item }
            var sanitized = item
            sanitized.content = CustomInstructions.removingWrapper(from: item.content)
            return sanitized
        }
    }

    private func snapshot() -> ConversationSession {
        var session = conversation.session
        session.messages = items.filter { $0.id != "__optimistic__" }
        return session
    }

    /// Regeneration is a replacement branch, not another input on the existing remote session.
    /// Carry the retained local history into a fresh session and omit cursors/raw state that point
    /// at the exchange being replaced.
    private func replacementSnapshot(sessionID: String) -> ConversationSession {
        var session = snapshot()
        session.remoteSessionID = sessionID
        session.rawSession = nil
        session.lastRenderedEventID = nil
        return session
    }

    private func captureRegenerationBackup() {
        regenerateBackup = RegenerationBackup(
            items: items,
            remoteSessionID: conversation.remoteSessionID,
            rawSession: conversation.rawSession,
            lastRenderedEventID: conversation.lastRenderedEventID
        )
    }

    private func persist() {
        conversation.messages = items.filter { $0.id != "__optimistic__" }
    }

    private func fail(_ message: String) {
        if shouldAutomaticallyReconnect(after: message) {
            beginAutomaticReconnect()
            return
        }

        client.disconnect()
        automaticReconnectTask?.cancel()
        streamTask = nil
        pendingUserItem = nil
        clearInFlightInput()
        deferredOnboardTurn = nil

        // A failed regenerate: restore the exchange we optimistically removed rather than losing it.
        if restoreRegenerateBackup() {
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
        guard hasInFlightAttachments else { return false }
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

    private func updateLiveActivity(for event: ServerEvent) {
        switch event.type {
        case "tool_call":
            let toolName = event.payload[string: "name"] ?? "tool"
            liveActivity.update(
                conversationID: conversation.id,
                phase: .tool,
                headline: "Using \(toolName)",
                detail: liveActivityDetail(for: event.payload["args"]?.objectValue) ?? "Running a tool call",
                toolName: toolName
            )

        case "tool_result":
            liveActivity.update(
                conversationID: conversation.id,
                phase: .running,
                headline: "\(agent.displayName) is reading results",
                detail: "Tool call completed"
            )

        case "llm_call", "thinking", "intent":
            liveActivity.update(
                conversationID: conversation.id,
                phase: .running,
                headline: "\(agent.displayName) is thinking",
                detail: event.payload[string: "model"] ?? event.payload[string: "ack"] ?? "Planning the next step"
            )

        case "assistant":
            liveActivity.update(
                conversationID: conversation.id,
                phase: .running,
                headline: "\(agent.displayName) is replying",
                detail: "Streaming the final response"
            )

        case "ask_user":
            liveActivity.update(
                conversationID: conversation.id,
                phase: .waiting,
                headline: "Needs your reply",
                detail: event.payload[string: "text"] ?? event.payload[string: "question"] ?? "Return to answer the agent"
            )

        case "approval_needed":
            let toolName = event.payload[string: "tool"] ?? "tool"
            liveActivity.update(
                conversationID: conversation.id,
                phase: .waiting,
                headline: "Approval needed",
                detail: event.payload[string: "description"] ?? "Review \(toolName)",
                toolName: toolName
            )

        case "plan_review":
            liveActivity.update(
                conversationID: conversation.id,
                phase: .waiting,
                headline: "Plan ready",
                detail: "Return to review the agent plan"
            )

        case "ONBOARD_REQUIRED":
            liveActivity.update(
                conversationID: conversation.id,
                phase: .waiting,
                headline: "Verification needed",
                detail: "Return to finish onboarding"
            )

        default:
            break
        }
    }

    private func updateLiveActivityAfterUserAction(_ detail: String) {
        liveActivity.update(
            conversationID: conversation.id,
            phase: .running,
            headline: "\(agent.displayName) is continuing",
            detail: detail
        )
    }

    private func liveActivityDetail(for arguments: [String: JSONValue]?) -> String? {
        guard let arguments else { return nil }
        let preferredKeys = ["path", "file_path", "command", "query", "url"]
        for key in preferredKeys {
            if let value = arguments[key]?.stringValue, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func userFacingError(_ message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("could not connect") ||
            lowercased.contains("connection refused") ||
            lowercased.contains("cannot connect") ||
            lowercased.contains("not connected") ||
            lowercased.contains("-1004") {
            return "Could not connect to this agent. Check that it is online and reachable from this iPhone."
        }

        return message
    }

    private var hasInFlightAttachments: Bool {
        guard let inFlightInput else { return false }
        return !inFlightInput.images.isEmpty || !inFlightInput.files.isEmpty
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
