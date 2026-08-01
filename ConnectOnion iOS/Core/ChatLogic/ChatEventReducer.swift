//
//  ChatEventReducer.swift
//
//  Purpose: Implements ChatEventReducer for the Core/ChatLogic module.
//  Collaborates with: ChatSessionStore.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum ChatEventReducer {
    static func apply(_ event: ServerEvent, to items: inout [ChatItem]) -> SessionActiveState? {
        switch event.type {
        case "tool_call":
            upsert(toolCall(from: event), in: &items)
            return .active

        case "tool_result":
            applyToolResult(event, to: &items)
            return .active

        case "llm_call":
            upsert(thinkingCall(from: event), in: &items)
            return .active

        case "llm_result":
            applyLLMResult(event, to: &items)
            return .active

        case "thinking":
            upsert(thinkingNote(from: event), in: &items)
            return .active

        case "assistant":
            guard let item = agentMessage(from: event) else { return nil }
            upsert(item, in: &items)
            return .active

        case "agent_image":
            applyAgentImage(event, to: &items)
            return .active

        case "intent":
            applyIntent(event, to: &items)
            return .active

        case "eval":
            applyEvaluation(event, to: &items)
            return .active

        case "compact":
            applyCompact(event, to: &items)
            return .active

        case "tool_blocked":
            upsert(toolBlocked(from: event), in: &items)
            return .active

        case "files_received":
            upsert(filesReceived(from: event), in: &items)
            return .active

        case "ulw_turns_reached":
            upsert(ulwTurnsReached(from: event), in: &items)
            return .waiting

        case "ask_user":
            upsert(askUser(from: event), in: &items)
            return .waiting

        case "approval_needed":
            upsert(approvalNeeded(from: event), in: &items)
            return .waiting

        case "plan_review":
            upsert(planReview(from: event), in: &items)
            return .waiting

        case "ONBOARD_REQUIRED":
            upsert(onboardRequired(from: event), in: &items)
            return .waiting

        case "ONBOARD_SUCCESS":
            upsert(onboardSuccess(from: event), in: &items)
            return .active

        case "RUNTIME_INPUT_ACK":
            return .active

        // The host uses a generic ERROR frame for an invalid invite code and keeps the pending
        // CONNECT alive so the client can retry on the same socket. Treat ERROR as an onboarding
        // rejection only while a submitted onboarding card is awaiting its result; unrelated agent
        // errors must retain their existing handling in ConnectOnionClient.
        case "ERROR" where hasSubmittedOnboardingAwaitingResult(in: items):
            let message = event.payload[string: "message"]
                ?? event.payload[string: "error"]
                ?? event.payload[string: "reason"]
            markLatestOnboardRejected(message: message, in: &items)
            return .waiting

        // Verification/invite was rejected by the host. The exact wire type isn't in this codebase
        // (only REQUIRED/SUCCESS are), so match the plausible names; an unmatched one still surfaces
        // via the default `unknown` item + the DEBUG log in ChatViewModel.handle(.server).
        case "ONBOARD_ERROR", "ONBOARD_FAILED", "ONBOARD_REJECTED", "ONBOARD_INVALID",
             "ONBOARD_DENIED", "VERIFICATION_FAILED", "INVITE_INVALID", "INVITE_REJECTED":
            let message = event.payload[string: "message"]
                ?? event.payload[string: "error"]
                ?? event.payload[string: "reason"]
            markLatestOnboardRejected(message: message, in: &items)
            return .waiting

        default:
            guard !ignoredEventTypes.contains(event.type) else { return nil }
            upsert(unknownItem(from: event), in: &items)
            return nil
        }
    }

    /// Applies an authoritative server snapshot without discarding a newer local turn. This mirrors
    /// the web client's user-turn boundary, while also retaining locally answered state for items
    /// represented in both timelines.
    static func reconcile(with serverItems: [ChatItem], items: inout [ChatItem]) {
        guard !serverItems.isEmpty else { return }

        let localItems = items
        var claimedLocalIndices: Set<Int> = []
        var exactIndices: [ChatItemIdentity: [Int]] = [:]
        for index in localItems.indices.reversed() {
            exactIndices[ChatItemIdentity(localItems[index]), default: []].append(index)
        }
        var semanticCursor = localItems.startIndex

        func matchingLocalIndex(for serverItem: ChatItem) -> Int? {
            let identity = ChatItemIdentity(serverItem)
            while let candidate = exactIndices[identity]?.popLast() {
                if !claimedLocalIndices.contains(candidate) {
                    return candidate
                }
            }

            // Different server/client ids are uncommon. Preserve ordered semantic matching without
            // restarting a full scan at index zero for every canonical item.
            if semanticCursor < localItems.endIndex {
                for index in semanticCursor..<localItems.endIndex
                where !claimedLocalIndices.contains(index)
                    && localItems[index].semanticallyMatches(serverItem) {
                    semanticCursor = localItems.index(after: index)
                    return index
                }
            }
            for index in localItems.startIndex..<semanticCursor
            where !claimedLocalIndices.contains(index)
                && localItems[index].semanticallyMatches(serverItem) {
                return index
            }
            return nil
        }

        var reconciled: [ChatItem] = []
        reconciled.reserveCapacity(max(serverItems.count, localItems.count))
        for serverItem in serverItems {
            guard let matchingIndex = matchingLocalIndex(for: serverItem) else {
                reconciled.append(serverItem)
                continue
            }
            claimedLocalIndices.insert(matchingIndex)
            let localItem = localItems[matchingIndex]
            reconciled.append(localItem.merging(serverItem))
        }

        let serverUserCount = serverItems.lazy.filter { $0.kind == .user }.count
        var localUserCount = 0
        var localSuffixStart = localItems.endIndex

        for index in localItems.indices where localItems[index].kind == .user {
            localUserCount += 1
            if localUserCount > serverUserCount {
                localSuffixStart = index
                break
            }
        }

        for localItem in localItems[localSuffixStart...] {
            if let index = reconciled.firstIndex(where: {
                $0.id == localItem.id && $0.kind == localItem.kind
            }) {
                reconciled[index] = localItem.merging(reconciled[index])
            } else {
                reconciled.append(localItem)
            }
        }

        items = reconciled
    }

    static func upsert(_ item: ChatItem, in items: inout [ChatItem]) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = items[index].merging(item)
        } else {
            items.append(item)
        }
    }

    static func markLatestAskUserAnswered(answer: String, in items: inout [ChatItem]) {
        guard let index = items.lastIndex(where: { $0.kind == .askUser && !$0.answered }) else { return }
        items[index].answered = true
        items[index].answer = answer
    }

    static func markLatestApprovalAnswered(approved: Bool, scope: String, mode: String?, in items: inout [ChatItem]) {
        guard let index = items.lastIndex(where: { $0.kind == .approvalNeeded && !$0.answered }) else { return }
        items[index].answered = true

        if approved {
            items[index].answer = scope == "session" ? "Approved for session" : "Approved"
        } else if mode == "reject_soft" {
            items[index].answer = "Skipped"
        } else {
            items[index].answer = "Rejected"
        }
    }

    static func markLatestOnboardSubmitted(inviteCode: String?, payment: Double?, in items: inout [ChatItem]) {
        guard let index = items.lastIndex(where: { $0.kind == .onboardRequired && !$0.answered }) else { return }
        items[index].answered = true
        items[index].reason = nil // clear any prior rejection error on a fresh submit
        if let inviteCode, !inviteCode.isEmpty {
            items[index].answer = "Invite submitted"
        } else if payment != nil {
            items[index].answer = "Payment submitted"
        } else {
            items[index].answer = "Verification submitted"
        }
    }

    /// Re-opens the most recent onboarding card so the user can retry, stashing the server's
    /// rejection message in `reason` (an otherwise-unused field on onboardRequired items) for display.
    static func markLatestOnboardRejected(message: String?, in items: inout [ChatItem]) {
        guard let index = items.lastIndex(where: { $0.kind == .onboardRequired }) else { return }
        items[index].answered = false
        items[index].answer = nil
        items[index].reason = message ?? "That code wasn't accepted. Check it and try again."
    }

    private static func hasSubmittedOnboardingAwaitingResult(in items: [ChatItem]) -> Bool {
        guard let requiredIndex = items.lastIndex(where: { $0.kind == .onboardRequired }),
              items[requiredIndex].answered else {
            return false
        }
        guard let successIndex = items.lastIndex(where: { $0.kind == .onboardSuccess }) else {
            return true
        }
        return successIndex < requiredIndex
    }

    static func markLatestPlanReviewAnswered(message: String, in items: inout [ChatItem]) {
        guard let index = items.lastIndex(where: { $0.kind == .planReview && !$0.answered }) else { return }
        items[index].answered = true
        items[index].answer = message.hasPrefix("Plan approved") ? "Plan approved" : "Revision requested"
    }
}

private struct ChatItemIdentity: Hashable {
    var id: ChatItem.ID
    var kind: ChatItemKind

    init(_ item: ChatItem) {
        id = item.id
        kind = item.kind
    }
}

extension ChatEventReducer {
    /// Protocol/telemetry frames (`AGENT_PROFILE`, `DASHBOARD_SNAPSHOT`, `user_input`, …) carry no
    /// user-facing content. The live `apply` path drops them via `ignoredEventTypes`; this lets the
    /// snapshot / restore / reconcile paths drop the same frames once they've already been decoded
    /// into `.unknown` chat items, so they don't resurface as noisy "Agent event: X" rows on reconnect.
    static func isSuppressedTelemetry(_ item: ChatItem) -> Bool {
        // Only suppress items carrying a genuine ignored protocol type. A typeless `.unknown` item can
        // still hold user-facing content (e.g. a `message` field with no `type`), and `""` is itself a
        // member of `ignoredEventTypes` — so guard against nil/empty before matching, or we'd silently
        // drop a legitimate row on the snapshot/restore paths.
        guard item.kind == .unknown, let type = item.eventType, !type.isEmpty else { return false }
        return ignoredEventTypes.contains(type)
    }
}

private extension ChatEventReducer {
    static var ignoredEventTypes: Set<String> {
        [
            "", "PING", "PONG", "CONNECTED", "OUTPUT", "ERROR",
            "SESSION_STATUS", "SESSION_MERGED", "session_sync", "mode_changed", "RECONNECTED",
            "AGENT_PROFILE", "DASHBOARD_SNAPSHOT", "user_input"
        ]
    }

    static func toolCall(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .toolCall)
        item.name = event.payload[string: "name"] ?? "tool"
        item.arguments = event.payload["args"]?.objectValue ?? [:]
        item.status = .running
        return item
    }

    static func applyToolResult(_ event: ServerEvent, to items: inout [ChatItem]) {
        let id = event.id ?? UUID().uuidString
        guard let index = items.firstIndex(where: { $0.id == id && $0.kind == .toolCall }) else {
            var item = ChatItem(id: id, kind: .toolCall)
            item.name = event.payload[string: "name"] ?? event.payload[string: "tool"] ?? "tool"
            item.status = event.payload[string: "status"] == "error" ? .error : .done
            item.result = event.payload[string: "result"]
            item.timingMS = event.payload[int: "timing_ms"]
            items.append(item)
            return
        }
        items[index].status = event.payload[string: "status"] == "error" ? .error : .done
        items[index].result = event.payload[string: "result"]
        items[index].timingMS = event.payload[int: "timing_ms"]
    }

    static func thinkingCall(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .thinking)
        item.status = .running
        item.model = event.payload[string: "model"]
        return item
    }

    static func applyLLMResult(_ event: ServerEvent, to items: inout [ChatItem]) {
        let id = event.id ?? UUID().uuidString
        guard let index = items.firstIndex(where: { $0.id == id && $0.kind == .thinking }) else {
            var item = ChatItem(id: id, kind: .thinking)
            item.status = event.payload[string: "status"] == "error" ? .error : .done
            item.durationMS = event.payload[int: "duration_ms"]
            item.model = event.payload[string: "model"]
            item.contextPercent = event.payload[double: "context_percent"]
            item.usage = decode(TokenUsage.self, from: event.payload["usage"])
            items.append(item)
            return
        }
        items[index].status = event.payload[string: "status"] == "error" ? .error : .done
        items[index].durationMS = event.payload[int: "duration_ms"]
        items[index].model = event.payload[string: "model"] ?? items[index].model
        items[index].contextPercent = event.payload[double: "context_percent"]
        items[index].usage = decode(TokenUsage.self, from: event.payload["usage"])
    }

    static func thinkingNote(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .thinking)
        item.status = .done
        item.content = event.payload[string: "content"] ?? ""
        item.name = event.payload[string: "kind"]
        return item
    }

    static func agentMessage(from event: ServerEvent) -> ChatItem? {
        guard let rawContent = event.payload[string: "content"] else { return nil }
        let content = AgentContentSanitizer.sanitize(rawContent)
        guard !content.isEmpty else { return nil }
        return ChatItem(id: event.id ?? UUID().uuidString, kind: .agent, content: content)
    }

    static func applyAgentImage(_ event: ServerEvent, to items: inout [ChatItem]) {
        guard let image = event.payload[string: "image"] else { return }

        // Attach to the CURRENT turn only: the last `.agent` at or after the last `.user`. The turn has
        // no reply item until its OUTPUT arrives, so "last agent anywhere" would glue the image onto the
        // previous turn's bubble. When there is no such item, hold the image in a content-less agent
        // row that the OUTPUT handler then fills with the reply text (see ChatViewModel), which keeps
        // image and answer in one bubble and lets reconcile match it by content.
        let lastUserIndex = items.lastIndex(where: { $0.kind == .user })
        let targetID: String? = {
            guard let index = items.lastIndex(where: { $0.kind == .agent }) else { return nil }
            if let lastUserIndex, index < lastUserIndex { return nil }
            return items[index].id
        }()

        // De-duplicate only within the current turn; a repeat of the same image on an earlier,
        // already-completed turn must be left alone.
        for index in items.indices.reversed()
        where items[index].kind == .agent
            && items[index].id != targetID
            && index >= (lastUserIndex ?? 0)
            && items[index].images.contains(image) {
            items[index].images.removeAll { $0 == image }
            if items[index].content.isEmpty && items[index].images.isEmpty {
                items.remove(at: index)
            }
        }

        if let targetID, let index = items.firstIndex(where: { $0.id == targetID }) {
            if !items[index].images.contains(image) {
                items[index].images.append(image)
            }
        } else {
            var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .agent)
            item.images = [image]
            items.append(item)
        }
    }

    static func applyIntent(_ event: ServerEvent, to items: inout [ChatItem]) {
        let id = event.id ?? UUID().uuidString
        if let index = items.firstIndex(where: { $0.id == id && $0.kind == .intent }) {
            let status = event.payload[string: "status"]
            if status == "understood" || event.payload[string: "ack"] != nil {
                items[index].status = .understood
            } else if status == "analyzing" {
                items[index].status = .analyzing
            } else if items[index].status == nil {
                items[index].status = .analyzing
            }
            items[index].ack = event.payload[string: "ack"] ?? items[index].ack
            items[index].isBuild = event.payload[bool: "is_build"] ?? items[index].isBuild
        } else {
            var item = ChatItem(id: id, kind: .intent)
            item.status = event.payload[string: "status"] == "understood"
                || event.payload[string: "ack"] != nil
                ? .understood
                : .analyzing
            item.ack = event.payload[string: "ack"]
            item.isBuild = event.payload[bool: "is_build"]
            items.append(item)
        }
    }

    static func applyEvaluation(_ event: ServerEvent, to items: inout [ChatItem]) {
        let id = event.id ?? UUID().uuidString
        var item = items.first(where: { $0.id == id && $0.kind == .evaluation }) ?? ChatItem(id: id, kind: .evaluation)
        let status = event.payload[string: "status"]
        if status == "done"
            || event.payload[bool: "passed"] != nil
            || event.payload[string: "summary"] != nil {
            item.status = .done
        } else if status == "evaluating" {
            item.status = .evaluating
        } else if item.status == nil {
            item.status = .evaluating
        }
        item.passed = event.payload[bool: "passed"] ?? item.passed
        item.content = event.payload[string: "summary"] ?? item.content
        item.expected = event.payload[string: "expected"] ?? item.expected
        item.evalPath = event.payload[string: "eval_path"] ?? item.evalPath
        upsert(item, in: &items)
    }

    static func applyCompact(_ event: ServerEvent, to items: inout [ChatItem]) {
        let id = event.id ?? UUID().uuidString
        var item = items.first(where: { $0.id == id && $0.kind == .compact }) ?? ChatItem(id: id, kind: .compact)
        item.status = ExecutionStatus(rawValue: event.payload[string: "status"] ?? "") ?? .compacting
        item.contextPercent = event.payload[double: "context_percent"]
        item.content = event.payload[string: "message"] ?? event.payload[string: "error"] ?? item.content
        upsert(item, in: &items)
    }

    static func toolBlocked(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .toolBlocked)
        item.tool = event.payload[string: "tool"]
        item.reason = event.payload[string: "reason"]
        item.content = event.payload[string: "message"] ?? ""
        item.command = event.payload[string: "command"]
        return item
    }

    static func filesReceived(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .filesReceived)
        item.receivedFiles = decode([ReceivedFile].self, from: event.payload["files"]) ?? []
        return item
    }

    static func ulwTurnsReached(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .ulwTurnsReached)
        item.turnsUsed = event.payload[int: "turns_used"]
        item.maxTurns = event.payload[int: "max_turns"]
        if let turnsUsed = item.turnsUsed, let maxTurns = item.maxTurns {
            item.content = "Ultra work limit reached (\(turnsUsed)/\(maxTurns) turns)"
        } else {
            item.content = "Ultra work limit reached"
        }
        return item
    }

    static func unknownItem(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .unknown)
        item.eventType = event.type.isEmpty ? "unknown" : event.type
        item.rawPayload = event.payload
        item.content = event.payload[string: "message"]
            ?? event.payload[string: "text"]
            ?? event.payload[string: "reason"]
            ?? "Agent event: \(item.eventType ?? "unknown")"
        return item
    }

    static func askUser(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .askUser)
        item.content = event.payload[string: "text"] ?? event.payload[string: "question"] ?? ""
        item.options = event.payload["options"]?.arrayValue?.compactMap(\.stringValue) ?? []
        item.multiSelect = event.payload[bool: "multi_select"] ?? false
        item.inputType = event.payload[string: "input_type"]
        item.fields = decode([AskUserField].self, from: event.payload["fields"]) ?? []
        return item
    }

    static func approvalNeeded(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .approvalNeeded)
        item.tool = event.payload[string: "tool"]
        item.arguments = event.payload["arguments"]?.objectValue ?? [:]
        item.description = event.payload[string: "description"]
        item.batchRemaining = decode([BatchApproval].self, from: event.payload["batch_remaining"]) ?? []
        return item
    }

    static func planReview(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .planReview)
        item.planContent = event.payload[string: "plan_content"] ?? ""
        return item
    }

    static func onboardRequired(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? "onboard-required", kind: .onboardRequired)
        item.methods = event.payload["methods"]?.arrayValue?.compactMap(\.stringValue) ?? []
        item.paymentAmount = event.payload[double: "payment_amount"]
        item.paymentAddress = event.payload[string: "payment_address"]
        return item
    }

    static func onboardSuccess(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .onboardSuccess)
        item.level = event.payload[string: "level"]
        item.content = event.payload[string: "message"] ?? "Verification completed"
        return item
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: JSONValue?) -> T? {
        guard let value, let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

private extension ChatItem {
    func semanticallyMatches(_ other: ChatItem) -> Bool {
        guard kind == other.kind else { return false }

        switch kind {
        case .user, .agent:
            return content == other.content
        case .thinking:
            return !content.isEmpty || !other.content.isEmpty
                ? content == other.content
                : model == other.model
        case .toolCall:
            return name == other.name && arguments == other.arguments
        case .askUser:
            return content == other.content
        case .approvalNeeded:
            return tool == other.tool && arguments == other.arguments && description == other.description
        case .onboardRequired:
            return methods == other.methods && paymentAmount == other.paymentAmount
        case .onboardSuccess:
            return level == other.level && content == other.content
        case .intent:
            return ack == other.ack && isBuild == other.isBuild
        case .evaluation:
            return evalPath == other.evalPath && content == other.content
        case .compact:
            return content == other.content && contextPercent == other.contextPercent
        case .toolBlocked:
            return tool == other.tool && reason == other.reason && command == other.command
        case .planReview:
            return planContent == other.planContent
        case .filesReceived:
            return receivedFiles == other.receivedFiles
        case .ulwTurnsReached:
            return turnsUsed == other.turnsUsed && maxTurns == other.maxTurns
        case .unknown:
            return eventType == other.eventType && content == other.content
        }
    }

    func merging(_ other: ChatItem) -> ChatItem {
        var copy = self
        copy.createdAt = createdAt
        copy.content = other.content.isEmpty ? content : other.content
        if !other.images.isEmpty { copy.images = other.images }
        if !other.files.isEmpty { copy.files = other.files }
        copy.name = other.name ?? name
        if !other.arguments.isEmpty { copy.arguments = other.arguments }
        if other.status == .running, status == .done || status == .error {
            copy.status = status
        } else {
            copy.status = other.status ?? status
        }
        copy.result = other.result ?? result
        copy.timingMS = other.timingMS ?? timingMS
        copy.model = other.model ?? model
        copy.durationMS = other.durationMS ?? durationMS
        copy.contextPercent = other.contextPercent ?? contextPercent
        copy.usage = other.usage ?? usage
        if !other.options.isEmpty { copy.options = other.options }
        copy.multiSelect = other.multiSelect
        copy.inputType = other.inputType ?? inputType
        if !other.fields.isEmpty { copy.fields = other.fields }
        copy.answered = other.answered || answered
        copy.answer = other.answer ?? answer
        copy.tool = other.tool ?? tool
        copy.description = other.description ?? description
        if !other.batchRemaining.isEmpty { copy.batchRemaining = other.batchRemaining }
        if !other.methods.isEmpty { copy.methods = other.methods }
        copy.paymentAmount = other.paymentAmount ?? paymentAmount
        copy.paymentAddress = other.paymentAddress ?? paymentAddress
        copy.level = other.level ?? level
        copy.ack = other.ack ?? ack
        copy.isBuild = other.isBuild ?? isBuild
        copy.passed = other.passed ?? passed
        copy.expected = other.expected ?? expected
        copy.evalPath = other.evalPath ?? evalPath
        copy.reason = other.reason ?? reason
        copy.command = other.command ?? command
        copy.planContent = other.planContent ?? planContent
        if !other.receivedFiles.isEmpty { copy.receivedFiles = other.receivedFiles }
        copy.turnsUsed = other.turnsUsed ?? turnsUsed
        copy.maxTurns = other.maxTurns ?? maxTurns
        copy.eventType = other.eventType ?? eventType
        if !other.rawPayload.isEmpty { copy.rawPayload = other.rawPayload }
        return copy
    }
}
