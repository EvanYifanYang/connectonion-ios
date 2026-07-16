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
    var sessionState: SessionActiveState = .idle
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
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var pendingUserItem: ChatItem?
    @ObservationIgnored private var inFlightInput: AgentInput?
    @ObservationIgnored private var inFlightUserItemID: String?
    @ObservationIgnored private var inFlightWasFirstPrompt = false
    @ObservationIgnored private var optimisticUserItemID: String?
    @ObservationIgnored private var automaticReconnectAttempts = 0
    @ObservationIgnored private var automaticReconnectTask: Task<Void, Never>?
    @ObservationIgnored private var regenerateBackup: [ChatItem]?
    private var deferredOnboardInput: AgentInput?

    init(conversation: ConversationRecord, agent: AgentConfig, client: ConnectOnionClientProviding? = nil) {
        self.conversation = conversation
        self.agent = agent
        items = conversation.messages
        clientOverride = client
        finalizeRunningItems() // restored items must never resume the live "running" animation
        lastResponseModel = items.last { $0.kind == .thinking && $0.model?.isEmpty == false }?.model
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

    var shouldShowFirstPromptSuggestions: Bool {
        !hasCommittedUserMessage &&
            pendingOnboard == nil &&
            deferredOnboardInput == nil &&
            errorMessage == nil &&
            sessionState != .connecting &&
            sessionState != .reconnecting
    }

    func send(_ input: AgentInput) {
        send(input.prompt, images: input.images, files: input.files)
    }

    func send(_ prompt: String, images: [String] = [], files: [FileAttachment] = []) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !images.isEmpty || !files.isEmpty else { return }

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

    /// Re-run the most recent user turn: drop it and its reply, then send the same input again so a
    /// fresh response streams in its place (no duplicate user bubble). `send` already cancels any
    /// in-flight stream.
    func regenerate() {
        guard let lastUserIndex = items.lastIndex(where: { $0.kind == .user }) else { return }
        let userItem = items[lastUserIndex]
        regenerateBackup = items // restore this if the resend fails, so we don't lose the old exchange
        items.removeSubrange(lastUserIndex...)
        persist()
        send(userItem.content, images: userItem.images, files: userItem.files)
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
        client.disconnect()
        pendingUserItem = nil
        clearInFlightInput()
        deferredOnboardInput = nil
        finalizeRunningItems() // stop the peeling-onion animation on any half-finished item
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

    private var hasCommittedUserMessage: Bool {
        items.contains { item in
            item.kind == .user && item.id != optimisticUserItemID
        }
    }

    private func handle(_ event: ConnectOnionClientEvent) {
        switch event {
        case .connected(let sessionID, let status, _, let session, let chatItems):
            conversation.remoteSessionID = sessionID.isEmpty ? conversation.remoteSessionID : sessionID
            conversation.rawSession = session
            if !chatItems.isEmpty {
                items = chatItems
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
            }
            // A fresh assistant reply arrived via the reducer (the usual path for a real agent) — type
            // it out client-side. A merged/incremental update keeps the same id, so it won't retrigger.
            if event.type == "assistant",
               let lastAgent = items.last(where: { $0.kind == .agent }),
               lastAgent.id != previousAgentID {
                streamingMessageID = lastAgent.id
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
            if !chatItems.isEmpty {
                items = chatItems
            }
            if !result.isEmpty, items.last(where: { $0.kind == .agent })?.content != result {
                let agentItem = ChatItem(kind: .agent, content: result)
                append(agentItem, animated: true, shouldPersist: false)
                streamingMessageID = agentItem.id // reveal this one with the typewriter effect
            }
            finalizeRunningItems()
            conversation.rawSession = session
            sessionState = .connected
            stopTimer()
            persist()
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
        var session = conversation.session
        session.messages = items.filter { $0.id != "__optimistic__" }
        return session
    }

    private func persist() {
        conversation.messages = items.filter { $0.id != "__optimistic__" }
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
