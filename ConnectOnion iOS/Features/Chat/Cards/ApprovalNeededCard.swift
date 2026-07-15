import SwiftUI

struct ApprovalNeededCard: View {
    var item: ChatItem
    var isPending: Bool
    var onResponse: (Bool, String, String?, String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Approval needed", systemImage: "shield")
                .font(.headline)

            if let tool = item.tool {
                Text(tool)
                    .font(.body.monospaced())
            }

            if let description = item.description {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isPending {
                ApprovalButtons(onResponse: onResponse)
            } else if let answer = item.answer {
                Label(answer, systemImage: item.answer == "Skipped" ? "forward.fill" : "checkmark.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(item.answer == "Skipped" ? Color.secondary : Color.green)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassSurface(cornerRadius: 14, tint: .green.opacity(0.08))
                    .accessibilityIdentifier(AccessibilityID.approvalStatus)
            }
        }
        .padding(14)
        .frame(maxWidth: 520, alignment: .leading)
        .glassSurface(cornerRadius: 18, tint: .orange.opacity(0.08))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 5)
    }
}

#Preview("Approval Needed") {
    ApprovalNeededCard(item: PreviewFixtures.sampleApproval, isPending: true, onResponse: { _, _, _, _ in })
        .padding()
}

#Preview("Approval Resolved") {
    ApprovalNeededCard(item: PreviewFixtures.sampleApproval, isPending: false, onResponse: { _, _, _, _ in })
        .padding()
}
