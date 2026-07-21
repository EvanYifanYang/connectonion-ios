//
//  AgentActivityGroup.swift
//
//  Purpose: Implements AgentActivityGroup for the Features/Chat/Timeline module.
//  Collaborates with: AgentBubble, CompactRow, EvaluationRow, FilesReceivedRow, IntentRow, MarkdownMessageView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import SwiftUI

/// A Codex-style summary for consecutive internal agent events. The transcript keeps the result and
/// user-action cards prominent while making the execution trace available on demand.
struct AgentActivityGroup: View {
    var items: [ChatItem]
    /// Stored on the reply at turn completion so the elapsed time survives later session snapshots.
    var durationMS: Int? = nil
    /// True only for the last activity group while its agent turn is executing.
    var isRunning = false

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    BreathingActivitySummary(text: summary, isRunning: isRunning)

                    Spacer(minLength: 8)

                    if let metricsSummary {
                        Text(metricsSummary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
                .padding(.vertical, 8)
                .padding(.leading, 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(summary)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(isExpanded ? "Collapses agent activity" : "Shows agent activity details")

            if isExpanded {
                // This stack is already nested inside the transcript's LazyVStack. Keeping the inner
                // group eager avoids nested lazy-layout gaps when the outer scroll view is restored.
                VStack(spacing: 2) {
                    // Empty "Thinking · N tok" rows (bare llm_call markers) repeat once per LLM step and
                    // carry no detail — the elapsed/token metrics already live in the summary. Hide them
                    // so the expanded trace shows the meaningful work (tool calls, real thinking notes).
                    ForEach(items.filter { !($0.kind == .thinking && $0.content.isEmpty) }) { item in
                        ChatItemView(item: item)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: String {
        var seen: Set<String> = []
        let labels = items
            .compactMap(\.activitySummary)
            .filter { seen.insert($0).inserted }
        let meaningful = labels.filter { $0 != "Thinking" && $0 != "Working" }
        let candidates = meaningful.isEmpty ? labels : meaningful
        return candidates.suffix(2).joined(separator: " / ").nilIfEmpty ?? "Agent activity"
    }

    private var metricsSummary: String? {
        let eventDurationMS = items.reduce(0) { partialResult, item in
            partialResult + (item.durationMS ?? 0) + (item.timingMS ?? 0)
        }
        let totalDurationMS = durationMS ?? eventDurationMS
        if totalDurationMS > 0 {
            return formattedDuration(totalDurationMS)
        }
        return nil
    }

    private var accessibilityValue: String {
        [isExpanded ? "Expanded" : "Collapsed", metricsSummary]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// Opacity-only animation keeps the running cue visible without changing row geometry or invalidating
/// the expandable activity details. Reduce Motion and completed turns use one static phase.
private struct BreathingActivitySummary: View {
    var text: String
    var isRunning: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .phaseAnimator(isRunning && !reduceMotion ? [false, true] : [false]) { content, dimmed in
                content.opacity(dimmed ? 0.42 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.05)
            }
    }
}

private extension ChatItem {
    var activitySummary: String? {
        switch kind {
        case .thinking:
            return compactSummary(content) ?? (status == .running ? "Working" : "Thinking")

        case .toolCall:
            return toolSummary

        case .intent:
            return compactSummary(ack ?? content) ?? "Planning"

        case .evaluation:
            if let summary = compactSummary(content) {
                return summary
            }
            return passed.map { $0 ? "Check passed" : "Check failed" } ?? "Checking result"

        case .compact:
            return compactSummary(content) ?? "Compacted context"

        case .toolBlocked:
            return compactSummary(content) ?? compactSummary(reason) ?? "Tool blocked"

        case .onboardSuccess:
            return compactSummary(content) ?? "Onboarding completed"

        case .filesReceived:
            let names = receivedFiles.prefix(2).map(\.name)
            if !names.isEmpty {
                return "Received \(names.joined(separator: ", "))"
            }
            return compactSummary(content) ?? "Files received"

        case .ulwTurnsReached:
            return compactSummary(content) ?? "Work limit reached"

        case .unknown:
            return compactSummary(content) ?? eventType.map { humanized($0) } ?? "Agent event"

        case .user, .agent, .askUser, .approvalNeeded, .onboardRequired, .planReview:
            return nil
        }
    }

    var toolSummary: String {
        let rawName = name?.components(separatedBy: "__").last ?? "tool"
        let action = toolAction(for: rawName)
        guard let target = preferredToolTarget else { return action }
        return clipped("\(action) \(target)", limit: 88)
    }

    var preferredToolTarget: String? {
        for key in ["path", "file_path", "query", "url", "command", "name"] {
            guard let value = arguments[key]?.stringValue,
                  let summary = compactSummary(value) else { continue }
            if key == "path" || key == "file_path" {
                return URL(fileURLWithPath: summary).lastPathComponent.nilIfEmpty ?? summary
            }
            return summary
        }
        return nil
    }
}

private func toolAction(for name: String) -> String {
    let lowercased = name.lowercased()
    if lowercased.contains("read") { return "Read" }
    if lowercased.contains("search") || lowercased.contains("query") { return "Search" }
    if lowercased.contains("write") || lowercased.contains("create") { return "Write" }
    if lowercased.contains("edit") || lowercased.contains("patch") { return "Edit" }
    if lowercased.contains("bash") || lowercased.contains("shell") || lowercased.contains("command") { return "Run" }
    if lowercased.contains("open") || lowercased.contains("fetch") || lowercased.contains("browse") { return "Open" }
    return humanized(name)
}

private func humanized(_ value: String) -> String {
    let words = value
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
        .split(separator: " ")
        .map(String.init)
        .joined(separator: " ")
    guard let first = words.first else { return "Agent activity" }
    return first.uppercased() + String(words.dropFirst())
}

private func compactSummary(_ value: String?) -> String? {
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

private func clipped(_ value: String, limit: Int) -> String {
    guard value.count > limit else { return value }
    return String(value.prefix(limit - 1)) + "…"
}

private func formattedDuration(_ milliseconds: Int) -> String {
    if milliseconds < 1_000 {
        return "\(milliseconds)ms"
    }
    if milliseconds < 60_000 {
        return String(format: "%.1fs", Double(milliseconds) / 1_000)
    }
    return (Double(milliseconds) / 1_000).formattedDuration
}

#Preview("Agent Activity — Collapsed") {
    AgentActivityGroup(items: [
        PreviewFixtures.sampleThinking,
        PreviewFixtures.sampleToolCall,
        PreviewFixtures.sampleEvaluation
    ])
    .padding()
}
