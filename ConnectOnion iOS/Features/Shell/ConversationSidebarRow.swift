import SwiftUI

struct ConversationSidebarRow: View {
    var conversation: ConversationRecord
    var agentName: String
    var isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var committedOffset: CGFloat = 0
    @State private var rowHeight: CGFloat = 64

    private let actionWidth: CGFloat = 74

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteAction
                .opacity(currentOffset < -8 ? 1 : 0)

            rowButton
                .offset(x: currentOffset)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    max(geometry.size.height, 64)
                } action: { height in
                    if rowHeight != height {
                        rowHeight = height
                    }
                }
        }
        .clipShape(.rect(cornerRadius: 16))
        .contentShape(.rect)
        .simultaneousGesture(horizontalSwipeGesture)
        .animation(AppMotion.quick, value: committedOffset)
        .animation(AppMotion.quick, value: currentOffset < -8)
        .accessibilityAction(named: "Delete") {
            commitDelete()
        }
    }

    private var rowButton: some View {
        Button(action: handleRowTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.bubble")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.body)
                        .lineLimit(2)
                    Text(agentName)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Menu("Conversation Actions", systemImage: "ellipsis") {
                    Button("Delete", systemImage: "trash", role: .destructive, action: commitDelete)
                }
                .labelStyle(.iconOnly)
            }
            .padding(10)
            .background(isSelected ? Color.primary.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 16))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conversation.title)
    }

    private var deleteAction: some View {
        Button(role: .destructive, action: commitDelete) {
            Image(systemName: "trash.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .frame(width: actionWidth, height: rowHeight)
        .background(Color.red, in: .rect(cornerRadius: 16))
        .accessibilityLabel("Delete \(conversation.title)")
        .accessibilityIdentifier(AccessibilityID.deleteConversation(conversation.id))
        .accessibilityHidden(currentOffset == 0)
    }

    private var currentOffset: CGFloat {
        clamped(committedOffset + dragTranslation)
    }

    private var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let proposedOffset = clamped(committedOffset + value.translation.width)

                withAnimation(AppMotion.expressive) {
                    committedOffset = proposedOffset < -(actionWidth * 0.45) ? -actionWidth : 0
                }
            }
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(0, max(-actionWidth, value))
    }

    private func commitDelete() {
        withAnimation(AppMotion.standard) {
            committedOffset = 0
        }
        onDelete()
    }

    private func handleRowTap() {
        if committedOffset < 0 {
            withAnimation(AppMotion.expressive) {
                committedOffset = 0
            }
        } else {
            onSelect()
        }
    }
}

#Preview("Conversation Row") {
    ConversationSidebarRow(
        conversation: PreviewFixtures.sampleConversation,
        agentName: "OpenOnion",
        isSelected: true,
        onSelect: {},
        onDelete: {}
    )
    .padding()
}

#Preview("Conversation Row Unselected") {
    ConversationSidebarRow(
        conversation: PreviewFixtures.sampleConversation,
        agentName: "A1",
        isSelected: false,
        onSelect: {},
        onDelete: {}
    )
    .padding()
}
