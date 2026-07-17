import Factory
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    private let agent: AgentConfig
    private let conversation: ConversationRecord

    var items: [ChatItem]
    var sessionState: SessionActiveState = .idle {
        didSet {
            guard sessionState != oldValue else { return }
            onSessionStateChange(sessionState)
        }
    }
    var errorMessage: String?
    var elapsedTime: TimeInterval = 0
    /// The freshly-arrived agent message that should type itself out (client-side reveal). Cleared once
    /// the bubble finishes revealing. Nil for restored/older messages, so they render in full.
    var streamingMessageID: ChatItem.ID?
    /// The model that produced the latest reply, shown as a footer under it. Captured from events (the
    /// server's final `chatItems` may drop the thinking row that carries it).
    var lastResponseModel: String?

    @ObservationIgnored
    @Injected(\.connectOnionClient) private var injectedClient: ConnectOnionClientProviding

    @ObservationIgnored
    @Injected(\.liveActivityController) private var liveActivity: AgentReplyLiveActivityController

    @ObservationIgnored private let clientOverride: ConnectOnionClientProviding?
    @ObservationIgnored private let onSessionStateChange: (SessionActiveState) -> Void
    @ObservationIgnored private let onReplyReady: () -> Void
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var persistTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var pendingUserItem: ChatItem?
    @ObservationIgnored private var inFlightInput: AgentInput?
    @ObservationIgnored private var inFlightUserItemID: String?
    @ObservationIgnored private var inFlightWasFirstPrompt = false
    @ObservationIgnored private var optimisticUserItemID: String?
    @ObservationIgnored private var automaticReconnectAttempts = 0
    @ObservationIgnored private var automaticReconnectTask: Task<Void, Never>?
    @ObservationIgnored private var regenerateBackup: [ChatItem]?
    @ObservationIgnored private var isPresentationActive = false
    // While regenerating we keep the locally-trimmed view (old turn removed + fresh reply) instead of
    // adopting the server's canonical list, which still contains the turn we just replaced.
    @ObservationIgnored private var isRegenerating = false
    private var deferredOnboardInput: AgentInput?

    init(
        conversation: ConversationRecord,
        agent: AgentConfig,
        client: ConnectOnionClientProviding? = nil,
        onSessionStateChange: @escaping (SessionActiveState) -> Void = { _ in },
        onReplyReady: @escaping () -> Void = {}
    ) {
        self.conversation = conversation
        self.agent = agent
        self.onSessionStateChange = onSessionStateChange
        self.onReplyReady = onReplyReady
        let storedItems = conversation.messages
        let sanitizedItems = AgentContentSanitizer.sanitize(storedItems)
        items = sanitizedItems
        clientOverride = client
        if sanitizedItems != storedItems {
            conversation.messages = sanitizedItems
        }
        finalizeRunningItems() // restored items must never resume the live "running" animation
        lastResponseModel = items.last { $0.kind == .agent && $0.model?.isEmpty == false }?.model
            ?? items.last { $0.kind == .thinking && $0.model?.isEmpty == false }?.model
        sessionState = items.isEmpty ? .idle : .connected
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

    /// Context usage is cumulative for the conversation, so expose the latest known value at the
    /// conversation level instead of attaching it to an individual activity group in the UI.
    var contextPercent: Double? {
        items.reversed().compactMap(\.contextPercent).first
    }

    func send(_ input: AgentInput) {
        send(input.prompt, images: input.images, files: input.files)
    }

    func send(_ prompt: String, images: [String] = [], files: [FileAttachment] = [], isRegenerate: Bool = false) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !files.isEmpty else { return }

        isRegenerating = isRegenerate
        errorMessage = nil
        streamingMessageID = nil
        automaticReconnectAttempts = 0
        automaticReconnectTask?.cancel()
        let input = AgentInput(prompt: trimmed, images: images, files: files)
        inFlightInput = input
        var userItem = ChatItem(kind: .user, content: trimmed)
        userItem.images = images
        userItem.files = files
        pendingUserItem = userItem
        sessionState = .connecting
        elapsedTime = 0
        stopTimer()
        liveActivity.start(conversationID: conversation.id, agentAddress: agent.address, agentName: agent.displayName)

        streamTask?.cancel()
        let session = snapshot()
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

    /// Refresh presentation-only state when a retained session is shown again. The session store
    /// deliberately survives navigation, so initialization-time sanitization alone is not enough.
    func prepareForPresentation() {
        isPresentationActive = true
        streamingMessageID = nil
        sanitizeAllContent()
    }

    func finishPresentation() {
        isPresentationActive = false
        // A typewriter task is cancelled when its view disappears. Clearing its identifier prevents
        // the same completed reply from restarting the animation when the chat is opened again.
        streamingMessageID = nil
    }

    /// Re-run the user turn that produced a particular reply. Regenerating an older reply creates a
    /// new branch, so dependent turns after it are removed together with the selected exchange.
    func regenerate(replyID: ChatItem.ID) {
        guard let replyIndex = items.firstIndex(where: { $0.id == replyID && $0.kind == .agent }),
              let userIndex = items[..<replyIndex].lastIndex(where: { $0.kind == .user }) else { return }
        let userItem = items[userIndex]
        regenerateBackup = items // restore this if the resend fails, so we don't lose the old exchange
        items.removeSubrange(userIndex...)
        persist()
        send(userItem.content, images: userItem.images, files: userItem.files, isRegenerate: true)
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
        let session = snapshot()
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
        sessionState = .active
        startTimer()
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
        sessionState = .active
        startTimer()
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
        sessionState = .active
        startTimer()
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
        sessionState = .active
        startTimer()
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
        client.disconnect()
        pendingUserItem = nil
        clearInFlightInput()
        deferredOnboardInput = nil
        finalizeRunningItems() // stop the peeling-onion animation on any half-finished item
        stopTimer()
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

    private func handle(_ event: ConnectOnionClientEvent) {
        switch event {
        case .connected(let sessionID, let status, let serverNewer, let session, let chatItems):
            conversation.remoteSessionID = sessionID.isEmpty ? conversation.remoteSessionID : sessionID
            if serverNewer {
                conversation.rawSession = session
                ChatEventReducer.reconcile(with: AgentContentSanitizer.sanitize(chatItems), items: &items)
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
            regenerateBackup = nil // the resend is producing events, so drop the restore snapshot
            let previousAgentID = items.last(where: { $0.kind == .agent })?.id
            if event.type == "ONBOARD_REQUIRED", inFlightWasFirstPrompt {
                deferredOnboardInput = inFlightInput
                discardInFlightUserPrompt()
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
                streamingMessageID = isPresentationActive ? lastAgent.id : nil
            }
            if let model = items.last(where: { $0.kind == .thinking && $0.model?.isEmpty == false })?.model {
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
            schedulePersist()
            if event.type == "ONBOARD_SUCCESS" {
                resumeDeferredOnboardInput()
            }

        case .output(let result, let serverNewer, let session, let chatItems):
            let sanitizedResult = AgentContentSanitizer.sanitize(result)
            // Capture turn-scoped metrics before a newer canonical snapshot can omit intermediate
            // events. They are persisted on the final reply below.
            let completedTurnDurationMS = currentTurnDurationMS
            let completedContextPercent = contextPercent
            automaticReconnectAttempts = 0
            automaticReconnectTask?.cancel()
            regenerateBackup = nil // the resend produced a reply, so drop the restore snapshot
            commitOptimisticUserPrompt()
            clearInFlightInput()
            clearOptimisticPlaceholder()
            let regenerating = isRegenerating
            isRegenerating = false
            // Only adopt a newer server snapshot, and reconcile it at a user-turn boundary so an
            // unacknowledged local turn and locally answered cards cannot be rolled back.
            if serverNewer, !regenerating {
                ChatEventReducer.reconcile(with: AgentContentSanitizer.sanitize(chatItems), items: &items)
            }
            // Ensure the fresh reply exists as the LAST item so it can be revealed. Guard on the last
            // *item* (not the last agent anywhere): on a regenerate the canonical list is skipped, so a
            // prior turn's identical reply must not be mistaken for this turn's — there the re-sent user
            // is the last item, so we still append the fresh bubble below it.
            if !sanitizedResult.isEmpty,
               !(items.last?.kind == .agent && items.last?.content == sanitizedResult) {
                let agentItem = ChatItem(kind: .agent, content: sanitizedResult)
                append(agentItem, animated: true, shouldPersist: false)
            }
            finalizeRunningItems()
            // Type the reply out client-side. The host server never emits a live "assistant" event — the
            // reply only ever arrives here in OUTPUT — so point the typewriter at the just-finished reply
            // however it landed (adopted from the canonical list or appended above). This is the single
            // place the reveal is triggered for a normal turn.
            if !sanitizedResult.isEmpty,
               let index = items.lastIndex(where: { $0.kind == .agent }),
               items[index].content == sanitizedResult {
                streamingMessageID = isPresentationActive ? items[index].id : nil
            }
            // Stamp the model onto the reply itself so the footer survives a reload — the thinking row
            // that carries it may not be present in the server's canonical list.
            if let model = lastResponseModel ?? items.last(where: { $0.kind == .thinking && $0.model?.isEmpty == false })?.model,
               let index = items.lastIndex(where: { $0.kind == .agent }) {
                items[index].model = model
            }
            if let index = items.lastIndex(where: { $0.kind == .agent }) {
                items[index].durationMS = completedTurnDurationMS
                    ?? currentTurnDurationMS
                    ?? items[index].durationMS
                items[index].contextPercent = completedContextPercent
                    ?? contextPercent
                    ?? items[index].contextPercent
            }
            conversation.rawSession = session
            sessionState = .connected
            stopTimer()
            persist()
            onReplyReady()
            liveActivity.complete(
                conversationID: conversation.id,
                headline: "Reply ready",
                detail: "\(agent.displayName) finished responding"
            )

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
        inFlightUserItemID = nil
        inFlightWasFirstPrompt = false
    }

    private func resumeDeferredOnboardInput() {
        guard let input = deferredOnboardInput else { return }
        deferredOnboardInput = nil
        Task { @MainActor [weak self] in
            self?.send(input)
        }
    }

    private func snapshot() -> ConversationSession {
        ConversationSession(
            id: conversation.id,
            agentAddress: conversation.agentAddress,
            remoteSessionID: conversation.remoteSessionID,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            mode: conversation.mode,
            messages: items.filter { $0.id != "__optimistic__" },
            rawSession: conversation.rawSession,
            lastRenderedEventID: conversation.lastRenderedEventID
        )
    }

    private func persist() {
        persistTask?.cancel()
        persistTask = nil
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
                let removedID = items[index].id
                items.remove(at: index)
                if streamingMessageID == removedID {
                    streamingMessageID = nil
                }
            }
        }
    }

    private func fail(_ message: String) {
        if shouldAutomaticallyReconnect(after: message) {
            beginAutomaticReconnect()
            return
        }

        automaticReconnectTask?.cancel()
        pendingUserItem = nil
        clearInFlightInput()
        deferredOnboardInput = nil

        // A failed regenerate: restore the exchange we optimistically removed rather than losing it.
        if let backup = regenerateBackup {
            regenerateBackup = nil
            items = backup
            finalizeRunningItems()
            errorMessage = userFacingError(message)
            sessionState = items.isEmpty ? .idle : .connected
            stopTimer()
            persist()
            return
        }

        commitOptimisticUserPrompt()
        clearOptimisticPlaceholder()
        finalizeRunningItems()
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

    private var currentTurnDurationMS: Int? {
        guard let userIndex = items.lastIndex(where: { $0.kind == .user }) else { return nil }
        let eventDurationMS = items[userIndex...].reduce(0) { partialResult, item in
            partialResult + (item.durationMS ?? 0) + (item.timingMS ?? 0)
        }
        if eventDurationMS > 0 {
            return eventDurationMS
        }

        let wallClockDurationMS = Int((elapsedTime * 1_000).rounded())
        return wallClockDurationMS > 0 ? wallClockDurationMS : nil
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
