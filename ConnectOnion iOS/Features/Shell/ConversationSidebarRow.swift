import SwiftUI

struct ConversationSidebarRow: View {
    var conversation: ConversationRecord
    var agentName: String
    var isSelected: Bool
    var onSelect: () -> Void
    var onRename: () -> Void
    var onRequestDelete: () -> Void
    var onDelete: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var committedOffset: CGFloat = 0
    @State private var rowHeight: CGFloat = 64
    // Set while a horizontal swipe is in progress so the touch-up that ends the swipe isn't also
    // delivered to the row's tap handler (which would immediately snap the just-opened row shut).
    @State private var didSwipe = false

    private let actionWidth: CGFloat = 74
    // Gap between the sliding card and the red delete pill, so the reveal reads as two separate
    // rounded tiles (native swipe-action look) instead of two r20 tiles kissing with corner notches —
    // and so the card's soft shadow lands on the gap, not on the red.
    private let actionGap: CGFloat = 14

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
            HStack(alignment: .center, spacing: 10) {
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

                Menu {
                    menuActions
                } label: {
                    Label("Conversation Actions", systemImage: "ellipsis")
                }
                .labelStyle(.iconOnly)
            }
            .padding(14)
            .sidebarCard(isSelected: isSelected)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conversation.title)
        .contextMenu { menuActions }
    }

    @ViewBuilder
    private var menuActions: some View {
        Button("Rename", systemImage: "pencil", action: onRename)
            .accessibilityIdentifier(AccessibilityID.renameConversationButton)
        Button("Delete Chat", systemImage: "trash", role: .destructive, action: onRequestDelete)
    }

    private var deleteAction: some View {
        Button(role: .destructive, action: commitDelete) {
            Image(systemName: "trash.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: actionWidth - actionGap, height: rowHeight)
                .background(Color.red, in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .frame(width: actionWidth, alignment: .trailing)
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
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height),
                   abs(value.translation.width) > 12 {
                    didSwipe = true
                }
            }
            .onEnded { value in
                // Clear the flag on the next runloop tick — after the synthesized tap (if any) has
                // already been swallowed by handleRowTap this event cycle.
                defer { DispatchQueue.main.async { didSwipe = false } }
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
        // Swallow the touch-up that concludes a swipe so it doesn't count as a tap.
        if didSwipe { return }

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
        onRename: {},
        onRequestDelete: {},
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
        onRename: {},
        onRequestDelete: {},
        onDelete: {}
    )
    .padding()
}
