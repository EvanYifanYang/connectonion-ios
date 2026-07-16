import SwiftUI

/// Renders a run of consecutive tool calls as one compact, collapsible card. A single call collapses to
/// its name + args; multiple calls (e.g. get_weather × 3) collapse to "N tool calls". Tapping reveals
/// each call's result. Replaces the old one-big-card-per-call layout.
struct ToolCallGroupCard: View {
    var items: [ChatItem]
    var pendingApprovalID: ChatItem.ID?
    var onApprovalResponse: (Bool, String, String?, String?) -> Void

    @State private var isExpanded = false

    private var hasPendingApproval: Bool {
        pendingApprovalID != nil && items.contains { $0.id == pendingApprovalID }
    }

    private var isExpandedEffective: Bool {
        isExpanded || hasPendingApproval
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.smooth(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    statusIcon(aggregateStatus, running: anyRunning)

                    if items.count == 1 {
                        Text(items[0].name ?? "tool")
                            .font(.callout.monospaced())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let preview = argsPreview(items[0]) {
                            Text(preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("\(items.count) tool calls")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpandedEffective ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(hasPendingApproval) // must stay open while a call awaits approval

            if isExpandedEffective {
                ForEach(items) { item in
                    detail(for: item)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 660, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func detail(for item: ChatItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if items.count > 1 {
                HStack(spacing: 6) {
                    statusIcon(item.status, running: item.status == .running)
                        .font(.footnote)
                    Text(item.name ?? "tool")
                        .font(.footnote.monospaced())
                    if let preview = argsPreview(item) {
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }

            if item.id == pendingApprovalID {
                ApprovalButtons(onResponse: onApprovalResponse)
            }

            if let result = item.result?.nilIfEmpty {
                Text(result)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 8))
            }
        }
    }

    // MARK: - Status

    private var anyRunning: Bool { items.contains { $0.status == .running } }

    private var aggregateStatus: ExecutionStatus? {
        if items.contains(where: { $0.status == .error }) { return .error }
        if anyRunning { return .running }
        if items.allSatisfy({ $0.status == .done }) { return .done }
        return items.first?.status
    }

    private func statusIcon(_ status: ExecutionStatus?, running: Bool) -> some View {
        Image(systemName: symbol(for: status))
            .foregroundStyle(tint(for: status))
            .symbolEffect(.pulse, options: .repeating, value: running)
    }

    private func symbol(for status: ExecutionStatus?) -> String {
        switch status {
        case .done: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        default: "circle.fill"
        }
    }

    private func tint(for status: ExecutionStatus?) -> Color {
        switch status {
        case .done: .green
        case .error: .red
        default: .secondary
        }
    }

    private func argsPreview(_ item: ChatItem) -> String? {
        guard !item.arguments.isEmpty else { return nil }
        let preview = item.arguments
            .sorted { $0.key < $1.key }
            .compactMap { key, value in value.stringValue.map { "\(key): \($0)" } ?? "\(key)" }
            .joined(separator: ", ")
        return preview.isEmpty ? nil : preview
    }
}

#Preview("Tool Group — multiple") {
    ToolCallGroupCard(
        items: [PreviewFixtures.sampleToolCall, PreviewFixtures.sampleToolCall],
        pendingApprovalID: nil,
        onApprovalResponse: { _, _, _, _ in }
    )
    .padding()
}

#Preview("Tool Group — single") {
    ToolCallGroupCard(
        items: [PreviewFixtures.sampleToolCall],
        pendingApprovalID: nil,
        onApprovalResponse: { _, _, _, _ in }
    )
    .padding()
}
