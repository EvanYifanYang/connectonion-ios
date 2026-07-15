import SwiftUI

struct ToolCallCard: View {
    var item: ChatItem
    var isPendingApproval: Bool
    var onApprovalResponse: (Bool, String, String?, String?) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusTint)
                        .symbolEffect(.pulse, options: .repeating, value: item.status == .running)

                    Text(item.name ?? "tool")
                        .font(.body.monospaced())
                        .lineLimit(1)

                    if let argsPreview {
                        Text(argsPreview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if let timing = item.timingMS {
                        Text(TimeInterval(timing) / 1000, format: .number.precision(.fractionLength(1)))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isPendingApproval {
                ApprovalButtons(onResponse: onApprovalResponse)
            }

            if isExpanded, let result = item.result?.nilIfEmpty {
                Text(result)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 12))
            }
        }
        .padding(12)
        .frame(maxWidth: 660, alignment: .leading)
        .glassSurface(cornerRadius: 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch item.status {
        case .done: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        default: "circle.fill"
        }
    }

    private var statusTint: Color {
        switch item.status {
        case .done: .green
        case .error: .red
        default: .secondary
        }
    }

    private var argsPreview: String? {
        guard !item.arguments.isEmpty else { return nil }
        let preview = item.arguments
            .sorted { $0.key < $1.key }
            .compactMap { key, value in value.stringValue.map { "\(key): \($0)" } ?? "\(key)" }
            .joined(separator: ", ")
        return preview.isEmpty ? nil : preview
    }
}

#Preview("Tool Call Done") {
    ToolCallCard(item: PreviewFixtures.sampleToolCall, isPendingApproval: false, onApprovalResponse: { _, _, _, _ in })
        .padding()
}

#Preview("Tool Call Pending Approval") {
    ToolCallCard(item: PreviewFixtures.sampleToolCallRunning, isPendingApproval: true, onApprovalResponse: { _, _, _, _ in })
        .padding()
}
