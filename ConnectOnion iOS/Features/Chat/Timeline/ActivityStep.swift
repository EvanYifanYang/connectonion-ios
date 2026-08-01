//
//  ActivityStep.swift
//
//  Purpose: One presentation vocabulary for every step inside the agent activity trace.
//  Collaborates with: ActivityStepRow, AgentActivityGroup, ChatItemView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

/// A single line in the expanded agent trace. Every in-trace `ChatItem` kind — thinking, tool calls,
/// intent, evaluation, compaction, blocked tools, received files, interim assistant messages — maps to
/// this one shape, so the trace renders as a uniform list instead of a stack of differently-tinted
/// cards. The collapsed group header reuses `label`, so the two can never drift apart.
struct ActivityStep: Equatable {
    enum Marker: Equatable {
        case idle
        case running
        case done
        case failed
    }

    var marker: Marker = .idle
    /// The primary one-line description ("Read foo.swift", "Working", "Understood").
    var label: String
    /// A short technical name rendered monospaced next to the label (the tool's name).
    var mono: String?
    /// Dimmer trailing context on the same line (tool arguments, a reason).
    var detail: String?
    /// Right-aligned metric (elapsed time, token count).
    var trailing: String?
    /// Long-form content revealed by the row's disclosure (a tool result, a full interim message).
    var body: String?

    static let fallback = ActivityStep(label: "Agent activity")
}

/// Shared text shaping for activity labels. These were private helpers of `AgentActivityGroup`; they
/// live here so the step mapping and the collapsed summary use exactly the same wording. Namespaced
/// rather than free functions because `humanized`/`clipped`/`compactSummary` are generic names in a
/// single-module target.
enum ActivityText {
    static func toolAction(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("read") { return "Read" }
        if lowercased.contains("search") || lowercased.contains("query") { return "Search" }
        if lowercased.contains("write") || lowercased.contains("create") { return "Write" }
        if lowercased.contains("edit") || lowercased.contains("patch") { return "Edit" }
        if lowercased.contains("bash") || lowercased.contains("shell") || lowercased.contains("command") { return "Run" }
        if lowercased.contains("open") || lowercased.contains("fetch") || lowercased.contains("browse") { return "Open" }
        return humanized(name)
    }

    static func humanized(_ value: String) -> String {
        let words = value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map(String.init)
            .joined(separator: " ")
        guard let first = words.first else { return "Agent activity" }
        return first.uppercased() + String(words.dropFirst())
    }

    static func compactSummary(_ value: String?) -> String? {
        guard let value else { return nil }
        let firstLine = value
            .split(whereSeparator: { $0.isNewline })
            .first
            .map(String.init)?
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstLine, !firstLine.isEmpty else { return nil }
        return clipped(firstLine, limit: 88)
    }

    static func clipped(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit - 1)) + "…"
    }

    static func formattedDuration(_ milliseconds: Int) -> String {
        if milliseconds < 1_000 {
            return "\(milliseconds)ms"
        }
        if milliseconds < 60_000 {
            return String(format: "%.1fs", Double(milliseconds) / 1_000)
        }
        return (Double(milliseconds) / 1_000).formattedDuration
    }
}

extension ChatItem {
    /// The trace presentation for this item, or nil for kinds that are never part of a trace
    /// (the user's own prompt and the interactive cards, which stay top-level).
    var activityStep: ActivityStep? {
        switch kind {
        case .thinking:
            return ActivityStep(
                marker: status == .running ? .running : .done,
                label: ActivityText.compactSummary(content) ?? (status == .running ? "Working" : "Thinking"),
                trailing: usage?.totalTokens.map { "\($0) tok" }
            )

        case .toolCall:
            let shortName = name?.components(separatedBy: "__").last ?? "tool"
            let action = ActivityText.toolAction(for: shortName)
            // The collapsed header shows `label`, so it must keep the target — otherwise two reads of
            // different files de-duplicate down to a bare "Read" and the header says nothing.
            let label = preferredToolTarget.map { ActivityText.clipped("\(action) \($0)", limit: 88) } ?? action
            return ActivityStep(
                marker: toolMarker,
                label: label,
                mono: shortName,
                detail: argumentsPreview.map { ActivityText.clipped($0, limit: 120) },
                trailing: timingMS.map(ActivityText.formattedDuration),
                body: result?.nilIfEmpty
            )

        case .intent:
            return ActivityStep(
                marker: status == .understood ? .done : .running,
                label: ActivityText.compactSummary(ack ?? content)
                    ?? (status == .understood ? "Understood" : "Understanding")
            )

        case .evaluation:
            let label = ActivityText.compactSummary(content)
                ?? ActivityText.compactSummary(expected)
                ?? (passed.map { $0 ? "Check passed" : "Check failed" } ?? "Checking result")
            return ActivityStep(
                marker: passed == false ? .failed : (status == .done ? .done : .running),
                label: label
            )

        case .compact:
            return ActivityStep(
                marker: status == .error ? .failed : .idle,
                label: ActivityText.compactSummary(content) ?? "Compacted context"
            )

        case .toolBlocked:
            let label = ActivityText.compactSummary(content) ?? ActivityText.compactSummary(reason) ?? "Tool blocked"
            let reasonSummary = ActivityText.compactSummary(reason)
            return ActivityStep(
                marker: .failed,
                label: label,
                detail: reasonSummary == label ? nil : reasonSummary
            )

        case .onboardSuccess:
            return ActivityStep(
                marker: .done,
                label: ActivityText.compactSummary(content) ?? "Onboarding completed"
            )

        case .filesReceived:
            let names = receivedFiles.map(\.name)
            let label: String = names.isEmpty
                ? (ActivityText.compactSummary(content) ?? "Files received")
                : "Received \(names.prefix(2).joined(separator: ", "))"
            return ActivityStep(
                marker: .done,
                label: label,
                body: names.count > 2 ? names.joined(separator: "\n") : nil
            )

        case .ulwTurnsReached:
            // `content` already embeds the counts, so a detail line would just repeat it.
            return ActivityStep(label: ActivityText.compactSummary(content) ?? "Work limit reached")

        case .agent:
            // Only reached for an INTERIM assistant message folded into the trace; a turn's final
            // answer stays a top-level bubble.
            let label = ActivityText.compactSummary(content) ?? "Assistant message"
            return ActivityStep(
                label: label,
                body: content.nilIfEmpty.flatMap { $0 == label ? nil : $0 }
            )

        case .unknown:
            // The reducer writes a placeholder `content` of "Agent event: <type>", so preferring
            // `content` would just re-advertise the raw protocol type in nicer typography.
            let generated = "Agent event: \(eventType ?? "unknown")"
            let summary = ActivityText.compactSummary(content)
            let isGenerated = summary == nil || summary == generated || summary?.hasPrefix(generated) == true
            let label = isGenerated
                ? (eventType.map(ActivityText.humanized) ?? "Agent event")
                : (summary ?? "Agent event")
            return ActivityStep(label: label, detail: eventType == label ? nil : eventType)

        case .user, .askUser, .approvalNeeded, .onboardRequired, .planReview:
            return nil
        }
    }

    private var toolMarker: ActivityStep.Marker {
        switch status {
        case .done: .done
        case .error: .failed
        case .running: .running
        default: .idle
        }
    }

    /// The most identifying argument of a tool call (the file it read, the query it ran). Ported from
    /// the retired activity helpers so the collapsed header can still name what was touched.
    private var preferredToolTarget: String? {
        for key in ["path", "file_path", "query", "url", "command", "name"] {
            guard let value = arguments[key]?.stringValue,
                  let summary = ActivityText.compactSummary(value) else { continue }
            if key == "path" || key == "file_path" {
                return URL(fileURLWithPath: summary).lastPathComponent.nilIfEmpty ?? summary
            }
            return summary
        }
        return nil
    }

    /// Ported from the retired `ToolCallCard` so arguments still read as dim trailing context.
    private var argumentsPreview: String? {
        guard !arguments.isEmpty else { return nil }
        let preview = arguments
            .sorted { $0.key < $1.key }
            .compactMap { key, value in value.stringValue.map { "\(key): \($0)" } ?? "\(key)" }
            .joined(separator: ", ")
        return preview.isEmpty ? nil : preview
    }
}
