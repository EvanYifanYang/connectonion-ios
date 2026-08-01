//
//  ActivityStepRow.swift
//
//  Purpose: The single uniform row every step inside the agent activity trace renders through.
//  Collaborates with: ActivityStep, AgentActivityGroup, ChatItemView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// One line of the expanded trace: a marker on a continuous hairline rail, a quiet label, dim detail,
/// and an optional right-aligned metric. Deliberately draws NO background, fill, or corner radius —
/// the trace reads as a single calm list (the pattern ChatGPT/Claude/Cursor use) rather than a stack
/// of tinted bubbles. Colour is reserved for failures.
struct ActivityStepRow: View {
    var step: ActivityStep

    @State private var isExpanded = false
    @State private var isBodyFullyShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let railInset: CGFloat = 18
    private static let markerWidth: CGFloat = 14
    private static let markerSpacing: CGFloat = 10

    var body: some View {
        HStack(alignment: .top, spacing: Self.markerSpacing) {
            marker
            content
        }
        .padding(.leading, Self.railInset)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        // The rail is drawn as a background so it is sized by the row. A flexible sibling inside the
        // HStack would be offered the scroll viewport's height and stretch the row instead.
        .background(alignment: .topLeading) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 1)
                .padding(.leading, Self.railInset + Self.markerWidth / 2 - 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(step.trailing ?? "")
    }

    // MARK: - Marker

    private var marker: some View {
        markerGlyph
            .foregroundStyle(tint)
            .frame(width: Self.markerWidth, height: 17)
            // Punch a hole in the rail so the glyph sits on the line rather than over it.
            .background(Color.appCanvas, in: .circle)
    }

    @ViewBuilder
    private var markerGlyph: some View {
        switch step.marker {
        case .idle:
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
        case .running:
            Image(systemName: "circle.dotted")
                .font(.system(size: 11, weight: .semibold))
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
        case .failed:
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
        }
    }

    /// Monochrome by default — only a failure earns real colour.
    private var tint: Color {
        switch step.marker {
        case .failed: .red
        case .running: Color.secondary
        case .done, .idle: Color.secondary.opacity(0.55)
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            headline
            if isExpanded, let body = step.body {
                bodyText(body)
            }
        }
    }

    private var headline: some View {
        Button {
            guard step.body != nil else { return }
            withAnimation(.smooth(duration: 0.18)) { isExpanded.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // A tool row leads with its monospaced name; the action verb it maps to is what the
                // collapsed header shows, so repeating it here would be redundant.
                Text(step.mono ?? step.label)
                    .appFont(.footnote)
                    .monospaced(step.mono != nil)
                    .foregroundStyle(step.marker == .failed ? .primary : .secondary)
                    .lineLimit(1)

                if let detail = step.detail {
                    Text(detail)
                        .appFont(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                if let trailing = step.trailing {
                    Text(trailing)
                        .appFont(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }

                if step.body != nil {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(step.body == nil)
    }

    private func bodyText(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(body)
                .appFont(.caption)
                .monospaced(step.mono != nil)
                .foregroundStyle(.secondary)
                .lineSpacing(2.5)
                .textSelection(.enabled)
                .lineLimit(isBodyFullyShown ? nil : 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isBodyFullyShown, body.count > 600 {
                Button("Show more") {
                    withAnimation(.smooth(duration: 0.18)) { isBodyFullyShown = true }
                }
                .appFont(.caption2)
                .foregroundStyle(.tertiary)
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 1)
        .padding(.bottom, 2)
    }

    private var accessibilityLabel: String {
        [step.mono ?? step.label, step.detail]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

#Preview("Activity Steps") {
    VStack(alignment: .leading, spacing: 0) {
        ActivityStepRow(step: ActivityStep(marker: .done, label: "Read", mono: "read_file", detail: "path: ChatViewModel.swift", trailing: "0.4s", body: "struct ChatViewModel { }"))
        ActivityStepRow(step: ActivityStep(marker: .running, label: "Working"))
        ActivityStepRow(step: ActivityStep(marker: .done, label: "Understood"))
        ActivityStepRow(step: ActivityStep(marker: .failed, label: "Run", mono: "bash", detail: "command: rm -rf /", trailing: "1.2s"))
        ActivityStepRow(step: ActivityStep(label: "Compacted context"))
    }
    .padding(.vertical)
    .background(Color.appCanvas)
}
