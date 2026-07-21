//
//  ConversationSidebarRow.swift
//
//  Purpose: Implements ConversationSidebarRow for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, EmptyStateHero.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct ConversationSidebarRow: View {
    var conversation: ConversationRecord
    var agentName: String
    var isSelected: Bool
    var isGenerating: Bool = false
    var onSelect: () -> Void
    var onRename: (String) -> Void
    var onRequestDelete: () -> Void
    var onDelete: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var committedOffset: CGFloat = 0
    @State private var rowHeight: CGFloat = 64
    @State private var isRenaming = false
    @State private var draftTitle = ""
    // Set while a horizontal swipe is in progress so the touch-up that ends the swipe isn't also
    // delivered to the row's tap handler (which would immediately snap the just-opened row shut).
    @State private var didSwipe = false

    private let actionWidth: CGFloat = 74
    // Gap between the sliding card and the red delete pill, so the reveal reads as two separate
    // rounded tiles (native swipe-action look) instead of two r20 tiles kissing with corner notches —
    // and so the card's soft shadow lands on the gap, not on the red.
    private let actionGap: CGFloat = 14

    var body: some View {
        if isRenaming {
            // Render the editor outside the swipe machinery (no drag gesture / offset / geometry
            // observer) so the field can take and hold keyboard focus cleanly.
            renameEditor
        } else {
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
    }

    private var renameEditor: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "text.bubble")
                .appFont(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 42, height: 42)

            InlineRenameField(
                text: $draftTitle,
                accessibilityID: AccessibilityID.conversationRenameField,
                onCommit: commitRename
            )

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 64)
        .sidebarCard(isSelected: isSelected)
        .contentShape(.rect)
    }

    private var rowButton: some View {
        Button(action: handleRowTap) {
            HStack(alignment: .center, spacing: 12) {
                conversationStatusIcon

                Text(conversation.title)
                    .appFont(.body)
                    .fontWeight(conversation.hasUnread ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                if isPinned {
                    Image(systemName: "pin.fill")
                        .appFont(.caption)
                        .foregroundStyle(Color.onion.opacity(0.7))
                }

                Text(relativeTime)
                    .appFont(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)

                Menu {
                    menuActions
                } label: {
                    Image(systemName: "ellipsis")
                        .appFont(.body, weight: .semibold)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                // No system press platter behind the glyph — it flashed as a stray square on the card.
                .menuStyle(.button)
                .buttonStyle(QuietPressButtonStyle())
                .accessibilityLabel("Conversation Actions")
                .accessibilityIdentifier(AccessibilityID.conversationActionsButton)
            }
            .padding(14)
            .frame(minHeight: 64)
            .sidebarCard(isSelected: isSelected, isPinned: isPinned)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conversation.title)
        .accessibilityValue(accessibilityStatus)
        // The id lives on the SELECT button itself (like AgentSidebarRow): a container-level id
        // shadows onto child buttons, so firstMatch could resolve to the ellipsis menu and a row
        // "tap" would open the actions menu instead of the chat.
        .accessibilityIdentifier(AccessibilityID.conversation(conversation.id))
        .contextMenu { menuActions }
    }

    private var isPinned: Bool {
        conversation.pinnedAt != nil
    }

    private var conversationStatusIcon: some View {
        ZStack(alignment: .topTrailing) {
            if isGenerating {
                OnionThinkingMark(active: true, diameter: 28)
            } else {
                Image(systemName: "text.bubble")
                    .appFont(.title3)
                    .foregroundStyle(.secondary)
            }

            if conversation.hasUnread {
                Circle()
                    .fill(Color.onion)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle().stroke(Color.appCanvas, lineWidth: 1.5)
                    }
                    .offset(x: 2, y: -2)
            }
        }
        .frame(width: 42, height: 42)
    }

    private var accessibilityStatus: String {
        switch (conversation.hasUnread, isGenerating) {
        case (true, true): "Unread, generating reply"
        case (true, false): "Unread"
        case (false, true): "Generating reply"
        case (false, false): ""
        }
    }

    @ViewBuilder
    private var menuActions: some View {
        Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin") { togglePin() }
        Button("Rename", systemImage: "pencil") { startRename() }
            .accessibilityIdentifier(AccessibilityID.renameConversationButton)
        Button("Delete Chat", systemImage: "trash", role: .destructive, action: onRequestDelete)
    }

    private func togglePin() {
        withAnimation(AppMotion.standard) {
            conversation.pinnedAt = isPinned ? nil : .now
        }
    }

    private func startRename() {
        draftTitle = conversation.title
        isRenaming = true
    }

    private func commitRename() {
        guard isRenaming else { return }
        isRenaming = false
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != conversation.title {
            onRename(trimmed)
        }
    }

    private var deleteAction: some View {
        Button(role: .destructive, action: commitDelete) {
            Image(systemName: "trash.fill")
                .appFont(.title3, weight: .semibold)
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

    /// Compact "time since the last activity" for the row (e.g. 5m, 3h, 2d), like a messaging app.
    private var relativeTime: String {
        let seconds = Date.now.timeIntervalSince(conversation.updatedAt)
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        case ..<604_800: return "\(Int(seconds / 86_400))d"
        default: return "\(Int(seconds / 604_800))w"
        }
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
        onRename: { _ in },
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
        onRename: { _ in },
        onRequestDelete: {},
        onDelete: {}
    )
    .padding()
}
