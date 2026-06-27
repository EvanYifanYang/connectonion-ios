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

    @ObservationIgnored
    @Injected(\.connectOnionClient) private var injectedClient: ConnectOnionClientProviding

    @ObservationIgnored private let clientOverride: ConnectOnionClientProviding?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var pendingUserItem: ChatItem?
    @ObservationIgnored private var inFlightInput: AgentInput?
    @ObservationIgnored private var inFlightUserItemID: String?
    @ObservationIgnored private var inFlightWasFirstPrompt = false
    @ObservationIgnored private var optimisticUserItemID: String?
    private var deferredOnboardInput: AgentInput?

    init(conversation: ConversationRecord, agent: AgentConfig, client: ConnectOnionClientProviding? = nil) {
        self.conversation = conversation
        self.agent = agent
        items = conversation.messages
        clientOverride = client
        sessionState = items.isEmpty ? .idle : .connected
    }

    deinit {
        streamTask?.cancel()
        timerTask?.cancel()
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
        let input = AgentInput(prompt: trimmed, images: images, files: files)
        inFlightInput = input
        var userItem = ChatItem(kind: .user, content: trimmed)
        userItem.images = images
        userItem.files = files
        pendingUserItem = userItem
        sessionState = .connecting
        elapsedTime = 0
        stopTimer()

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

    func reconnect() {
        errorMessage = nil
        sessionState = .reconnecting
        startTimer()

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
        stopTimer()
        sessionState = items.isEmpty ? .idle : .connected
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
            } else {
                sessionState = status == "running" ? .active : .connected
            }

        case .server(let event):
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
            commitOptimisticUserPrompt()
            clearInFlightInput()
            clearOptimisticPlaceholder()
            if !chatItems.isEmpty {
                items = chatItems
            }
            if !result.isEmpty, items.last(where: { $0.kind == .agent })?.content != result {
                append(ChatItem(kind: .agent, content: result), animated: true, shouldPersist: false)
            }
            conversation.rawSession = session
            sessionState = .connected
            stopTimer()
            persist()

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
        pendingUserItem = nil
        clearInFlightInput()
        deferredOnboardInput = nil
        commitOptimisticUserPrompt()
        clearOptimisticPlaceholder()
        errorMessage = userFacingError(message)
        sessionState = .disconnected
        stopTimer()
        persist()
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
