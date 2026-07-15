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

        default:
            return nil
        }
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
        if let inviteCode, !inviteCode.isEmpty {
            items[index].answer = "Invite submitted"
        } else if payment != nil {
            items[index].answer = "Payment submitted"
        } else {
            items[index].answer = "Verification submitted"
        }
    }

    static func markLatestPlanReviewAnswered(message: String, in items: inout [ChatItem]) {
        guard let index = items.lastIndex(where: { $0.kind == .planReview && !$0.answered }) else { return }
        items[index].answered = true
        items[index].answer = message.hasPrefix("Plan approved") ? "Plan approved" : "Revision requested"
    }
}

private extension ChatEventReducer {
    static func toolCall(from event: ServerEvent) -> ChatItem {
        var item = ChatItem(id: event.id ?? UUID().uuidString, kind: .toolCall)
        item.name = event.payload[string: "name"] ?? "tool"
        item.arguments = event.payload["args"]?.objectValue ?? [:]
        item.status = .running
        return item
    }

    static func applyToolResult(_ event: ServerEvent, to items: inout [ChatItem]) {
        let id = event.id ?? UUID().uuidString
        guard let index = items.firstIndex(where: { $0.id == id && $0.kind == .toolCall }) else { return }
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
        guard let index = items.firstIndex(where: { $0.id == id && $0.kind == .thinking }) else { return }
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
        guard let content = event.payload[string: "content"], !content.isEmpty else { return nil }
        return ChatItem(id: event.id ?? UUID().uuidString, kind: .agent, content: content)
    }

    static func applyAgentImage(_ event: ServerEvent, to items: inout [ChatItem]) {
        guard let image = event.payload[string: "image"] else { return }
        if let index = items.lastIndex(where: { $0.kind == .agent }) {
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
            items[index].status = event.payload[string: "status"] == "understood" ? .understood : .analyzing
            items[index].ack = event.payload[string: "ack"]
            items[index].isBuild = event.payload[bool: "is_build"]
        } else {
            var item = ChatItem(id: id, kind: .intent)
            item.status = event.payload[string: "status"] == "understood" ? .understood : .analyzing
            item.ack = event.payload[string: "ack"]
            item.isBuild = event.payload[bool: "is_build"]
            items.append(item)
        }
    }

    static func applyEvaluation(_ event: ServerEvent, to items: inout [ChatItem]) {
        let id = event.id ?? UUID().uuidString
        var item = items.first(where: { $0.id == id && $0.kind == .evaluation }) ?? ChatItem(id: id, kind: .evaluation)
        item.status = event.payload[string: "status"] == "done" ? .done : .evaluating
        item.passed = event.payload[bool: "passed"]
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
    func merging(_ other: ChatItem) -> ChatItem {
        var copy = self
        copy.createdAt = createdAt
        copy.content = other.content.isEmpty ? content : other.content
        if !other.images.isEmpty { copy.images = other.images }
        if !other.files.isEmpty { copy.files = other.files }
        copy.name = other.name ?? name
        if !other.arguments.isEmpty { copy.arguments = other.arguments }
        copy.status = other.status ?? status
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
        return copy
    }
}
