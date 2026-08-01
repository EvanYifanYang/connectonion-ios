//
//  AgentActivityGroup.swift
//
//  Purpose: Implements AgentActivityGroup for the Features/Chat/Timeline module.
//  Collaborates with: ActivityStep, ActivityStepRow, AgentBubble, MarkdownMessageView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import SwiftUI

/// The collapsed-by-default summary of one turn's internal execution. The transcript keeps the answer
/// and the user-action cards prominent; the trace is available on demand and, when opened, reads as a
/// single quiet list of `ActivityStepRow`s on a continuous rail — not a stack of tinted cards.
struct AgentActivityGroup: View {
    var items: [ChatItem]
    /// Stored on the reply at turn completion so the elapsed time survives later session snapshots.
    var durationMS: Int? = nil
    /// True only for the last activity group while its agent turn is executing.
    var isRunning = false

    @State private var isExpanded: Bool

    init(items: [ChatItem], durationMS: Int? = nil, isRunning: Bool = false, initiallyExpanded: Bool = false) {
        self.items = items
        self.durationMS = durationMS
        self.isRunning = isRunning
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    /// Empty "Thinking" rows (bare llm_call markers) repeat once per LLM step and carry no detail —
    /// the elapsed/token metrics already live in the summary, so they never become steps.
    private var visibleItems: [ChatItem] {
        items.filter { !($0.kind == .thinking && $0.content.isEmpty) }
    }

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
                // Zero spacing so each row's own padding sets the rhythm and the rails join into one
                // continuous line. This stack is already nested inside the transcript's LazyVStack, so
                // keeping the inner group eager avoids nested lazy-layout gaps on scroll restoration.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleItems) { item in
                        ChatItemView(item: item, isInTrace: true)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Reuses each step's own label so the collapsed header and the expanded rows never drift apart.
    private var summary: String {
        var seen: Set<String> = []
        let labels = items
            .compactMap { $0.activityStep?.label }
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
            return ActivityText.formattedDuration(totalDurationMS)
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

#Preview("Agent Activity — Collapsed") {
    AgentActivityGroup(items: [
        PreviewFixtures.sampleThinking,
        PreviewFixtures.sampleToolCall,
        PreviewFixtures.sampleEvaluation
    ])
    .padding()
}

#Preview("Agent Activity — Expanded") {
    AgentActivityGroup(
        items: [
            PreviewFixtures.sampleIntent,
            PreviewFixtures.sampleThinking,
            PreviewFixtures.sampleToolCall,
            PreviewFixtures.sampleEvaluation,
            PreviewFixtures.sampleCompact
        ],
        durationMS: 5_900,
        initiallyExpanded: true
    )
    .padding(.vertical)
    .background(Color.appCanvas)
}
