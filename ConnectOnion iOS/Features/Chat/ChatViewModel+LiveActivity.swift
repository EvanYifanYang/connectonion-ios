//
//  ChatViewModel+LiveActivity.swift
//
//  Purpose: Live Activity updates, user-facing error copy, and pure content helpers, split out of
//           ChatViewModel to keep that type within its size budget.
//  Collaborates with: AgentReplyLiveActivityController, ChatViewModel, CustomInstructions.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

extension ChatViewModel {
    /// Elapsed time for the turn in progress: event-reported durations when the host supplies them,
    /// otherwise the wall clock since the prompt was sent.
    var currentTurnDurationMS: Int? {
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

    static func sanitizingUserPrompts(in chatItems: [ChatItem]) -> [ChatItem] {
        chatItems.compactMap { item in
            guard item.kind == .user else { return item }
            var sanitized = item
            sanitized.content = CustomInstructions.visiblePrompt(from: item.content)
            if sanitized.content != item.content,
               sanitized.content.isEmpty,
               sanitized.images.isEmpty,
               sanitized.files.isEmpty {
                return nil
            }
            return sanitized
        }
    }

    /// Replies with block-level markdown render very differently once formatted, so the inline
    /// typewriter (which leaves block syntax uninterpreted) would show raw ``` / | / # and then snap to
    /// a card with a visible reflow. Detect the common block markers so those replies skip the reveal.
    static func hasBlockMarkdown(_ text: String) -> Bool {
        if text.contains("```") { return true } // fenced code block
        if text.contains("![") { return true }  // image — rendered as a block, never typed out
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") { return true } // heading
            if line.hasPrefix("|"), line.dropFirst().contains("|") { return true } // table row
        }
        return false
    }


    func updateLiveActivity(for event: ServerEvent) {
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

    func updateLiveActivityAfterUserAction(_ detail: String) {
        liveActivity.update(
            conversationID: conversation.id,
            phase: .running,
            headline: "\(agent.displayName) is continuing",
            detail: detail
        )
    }

    func liveActivityDetail(for arguments: [String: JSONValue]?) -> String? {
        guard let arguments else { return nil }
        let preferredKeys = ["path", "file_path", "command", "query", "url"]
        for key in preferredKeys {
            if let value = arguments[key]?.stringValue, !value.isEmpty {
                return value
            }
        }
        return nil
    }


    /// Some hosts place the final answer only in canonical chat items. Accept that form only when an
    /// assistant message follows the revised user message; retained history alone is not a replacement.
    func usableReplacementResult(result: String, chatItems: [ChatItem]) -> String? {
        if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return result
        }
        guard let lastUserIndex = chatItems.lastIndex(where: { $0.kind == .user }),
              let lastAgentIndex = chatItems.lastIndex(where: { $0.kind == .agent }),
              lastAgentIndex > lastUserIndex else {
            return nil
        }
        let canonicalResult = chatItems[lastAgentIndex].content
        return canonicalResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : canonicalResult
    }

}

struct RegenerationBackup {
    let items: [ChatItem]
    let remoteSessionID: String?
    let rawSession: JSONValue?
    let lastRenderedEventID: String?
}

struct DeferredOnboardTurn {
    let input: AgentInput
    let replacementSessionID: String?
    let userItemID: ChatItem.ID?
}
