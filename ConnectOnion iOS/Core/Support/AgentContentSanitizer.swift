//
//  AgentContentSanitizer.swift
//
//  Purpose: Implements AgentContentSanitizer for the Core/Support module.
//  Collaborates with: AccessibilityID, AttachmentEncoding, CustomInstructions, HexCoding, JSONValue, PersonalisationPreferences.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum AgentContentSanitizer {
    private static let openingTokens = ["<system-reminder", "<system_reminder"]
    private static let closingTokens = ["</system-reminder", "</system_reminder"]

    static func sanitize(_ content: String) -> String {
        var result = content

        while let openingRange = earliestRange(of: openingTokens, in: result) {
            guard let openingEnd = result.range(
                of: ">",
                range: openingRange.lowerBound..<result.endIndex
            ) else {
                result.removeSubrange(openingRange.lowerBound..<result.endIndex)
                break
            }

            let remainder = openingEnd.upperBound..<result.endIndex
            guard let closingRange = earliestRange(of: closingTokens, in: result, range: remainder),
                  let closingEnd = result.range(of: ">", range: closingRange.lowerBound..<result.endIndex) else {
                // Treat an unterminated reminder as internal content through the end of the message.
                result.removeSubrange(openingRange.lowerBound..<result.endIndex)
                break
            }

            result.removeSubrange(openingRange.lowerBound..<closingEnd.upperBound)
        }

        // Remove orphaned closing tags without hiding the surrounding user-facing answer.
        while let closingRange = earliestRange(of: closingTokens, in: result) {
            guard let closingEnd = result.range(
                of: ">",
                range: closingRange.lowerBound..<result.endIndex
            ) else {
                result.removeSubrange(closingRange.lowerBound..<result.endIndex)
                break
            }
            result.removeSubrange(closingRange.lowerBound..<closingEnd.upperBound)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sanitize(_ item: ChatItem) -> ChatItem? {
        // Protocol/telemetry frames leak in as `.unknown` items on snapshot/reconnect and render as
        // noisy "Agent event: X" rows — drop them before any content cleaning.
        if ChatEventReducer.isSuppressedTelemetry(item) { return nil }

        var sanitized = item
        let containedInternalContent = item.containsInternalReminder
        guard containedInternalContent else { return item }

        sanitized.content = sanitize(item.content)
        sanitized.result = sanitize(item.result)
        sanitized.answer = sanitize(item.answer)
        sanitized.description = sanitize(item.description)
        sanitized.ack = sanitize(item.ack)
        sanitized.expected = sanitize(item.expected)
        sanitized.reason = sanitize(item.reason)
        sanitized.command = sanitize(item.command)
        sanitized.planContent = sanitize(item.planContent)
        sanitized.options = item.options.map(sanitize)
        sanitized.fields = item.fields.map { field in
            var copy = field
            copy.label = sanitize(field.label)
            copy.placeholder = sanitize(field.placeholder)
            return copy
        }
        sanitized.batchRemaining = item.batchRemaining.map { approval in
            var copy = approval
            copy.arguments = sanitize(approval.arguments)
            return copy
        }
        sanitized.arguments = item.arguments.mapValues(sanitize)
        sanitized.rawPayload = item.rawPayload.mapValues(sanitize)

        // Preserve ordinary empty state/tool rows, but remove any row whose only visible payload was
        // an internal reminder. This covers reminders misclassified by a host as user/unknown events,
        // not just assistant messages.
        guard sanitized.hasVisiblePayload else {
            return nil
        }
        return sanitized
    }

    static func sanitize(_ items: [ChatItem]) -> [ChatItem] {
        items.compactMap { sanitize($0) }
    }

    private static func earliestRange(
        of tokens: [String],
        in content: String,
        range: Range<String.Index>? = nil
    ) -> Range<String.Index>? {
        let searchRange = range ?? content.startIndex..<content.endIndex
        return tokens
            .compactMap { content.range(of: $0, options: .caseInsensitive, range: searchRange) }
            .min { $0.lowerBound < $1.lowerBound }
    }

    private static func sanitize(_ content: String?) -> String? {
        guard let content else { return nil }
        return sanitize(content).nilIfEmpty
    }

    private static func sanitize(_ value: JSONValue) -> JSONValue {
        switch value {
        case .string(let content):
            return .string(sanitize(content))
        case .object(let object):
            return .object(object.mapValues(sanitize))
        case .array(let values):
            return .array(values.map(sanitize))
        case .number, .bool, .null:
            return value
        }
    }

    fileprivate static func containsInternalReminder(_ content: String) -> Bool {
        earliestRange(of: openingTokens + closingTokens, in: content) != nil
    }
}

private extension ChatItem {
    var containsInternalReminder: Bool {
        let textFields = [
            content, result, answer, description, ack, expected, reason, command, planContent
        ].compactMap { $0 }

        return textFields.contains(where: AgentContentSanitizer.containsInternalReminder)
            || options.contains(where: AgentContentSanitizer.containsInternalReminder)
            || fields.contains(where: {
                AgentContentSanitizer.containsInternalReminder($0.label)
                    || ($0.placeholder.map(AgentContentSanitizer.containsInternalReminder) ?? false)
            })
            || batchRemaining.contains(where: {
                AgentContentSanitizer.containsInternalReminder($0.arguments)
            })
            || arguments.values.contains(where: \.containsInternalReminder)
            || rawPayload.values.contains(where: \.containsInternalReminder)
    }

    var hasVisiblePayload: Bool {
        switch kind {
        case .user, .agent:
            return !content.isEmpty || !images.isEmpty || !files.isEmpty
        case .thinking:
            return !content.isEmpty || model?.isEmpty == false || status != nil
        case .toolCall:
            return name?.isEmpty == false || !arguments.isEmpty || result?.isEmpty == false
        case .askUser:
            return !content.isEmpty || !options.isEmpty || !fields.isEmpty
        case .approvalNeeded:
            return tool?.isEmpty == false || description?.isEmpty == false || !arguments.isEmpty
        case .onboardRequired:
            return !methods.isEmpty || paymentAmount != nil || paymentAddress?.isEmpty == false
        case .onboardSuccess, .ulwTurnsReached, .unknown:
            return !content.isEmpty
        case .intent:
            return !content.isEmpty || ack?.isEmpty == false
        case .evaluation:
            return !content.isEmpty || passed != nil || expected?.isEmpty == false
        case .compact:
            return !content.isEmpty || contextPercent != nil || status != nil
        case .toolBlocked:
            return !content.isEmpty || reason?.isEmpty == false || command?.isEmpty == false
        case .planReview:
            return planContent?.isEmpty == false
        case .filesReceived:
            return !receivedFiles.isEmpty
        }
    }
}

private extension JSONValue {
    var containsInternalReminder: Bool {
        switch self {
        case .string(let content):
            return AgentContentSanitizer.containsInternalReminder(content)
        case .object(let object):
            return object.values.contains(where: \.containsInternalReminder)
        case .array(let values):
            return values.contains(where: \.containsInternalReminder)
        case .number, .bool, .null:
            return false
        }
    }
}
