import SwiftUI
import UIKit

private let transcriptBottomAnchorID = "__connectonion_transcript_bottom__"

struct ChatMessageList: View {
    var items: [ChatItem]
    var pendingAskUser: ChatItem?
    var pendingApproval: ChatItem?
    var pendingOnboard: ChatItem?
    var pendingPlanReview: ChatItem?
    var onAskUserResponse: (String) -> Void
    var onApprovalResponse: (Bool, String, String?, String?) -> Void
    var onOnboardSubmit: (String?, Double?) -> Void
    var onPlanReviewResponse: (String) -> Void
    var onRegenerate: (ChatItem.ID) -> Void = { _ in }
    var streamingMessageID: ChatItem.ID?
    var onStreamComplete: (ChatItem.ID) -> Void = { _ in }
    var responseModel: String?

    @State private var transcriptPosition = ScrollPosition(
        id: transcriptBottomAnchorID,
        anchor: .bottom
    )
    @State private var isNearBottom = true
    @State private var followsTail = true

    private var lastAgentID: ChatItem.ID? {
        items.last { $0.kind == .agent }?.id
    }

    private var newestUserID: ChatItem.ID? {
        items.last { $0.kind == .user }?.id
    }

    /// User-visible messages and action cards remain in the primary timeline. Consecutive execution
    /// events collapse into a single Codex-style activity summary.
    private enum RenderUnit: Identifiable {
        case item(ChatItem)
        case activityGroup(id: String, items: [ChatItem], durationMS: Int?)

        var id: String {
            switch self {
            case .item(let item): item.id
            case .activityGroup(let id, _, _): id
            }
        }
    }

    private var renderUnits: [RenderUnit] {
        var units: [RenderUnit] = []
        var activityItems: [ChatItem] = []
        func flushActivity(completedBy reply: ChatItem? = nil) {
            guard !activityItems.isEmpty else { return }
            units.append(.activityGroup(
                id: "activity-\(activityItems[0].id)",
                items: activityItems,
                durationMS: reply?.durationMS
            ))
            activityItems.removeAll()
        }

        for item in items {
            if item.kind.isPrimaryTimelineContent {
                flushActivity(completedBy: item.kind == .agent ? item : nil)
                units.append(.item(item))
            } else {
                activityItems.append(item)
            }
        }
        flushActivity()
        return units
    }

    /// Keep scroll invalidation cheap. Comparing the complete `[ChatItem]` value also compares long
    /// message bodies and raw event payloads on every streamed event, which can stall the main actor.
    private var scrollUpdateToken: ScrollUpdateToken {
        let lastItem = items.last
        return ScrollUpdateToken(
            itemCount: items.count,
            lastItemID: lastItem?.id,
            lastContentLength: lastItem?.content.count ?? 0,
            lastResultLength: lastItem?.result?.count ?? 0,
            lastImageCount: lastItem?.images.count ?? 0,
            lastStatus: lastItem?.status?.rawValue,
            lastAnswered: lastItem?.answered ?? false,
            streamingMessageID: streamingMessageID
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(renderUnits) { unit in
                    switch unit {
                    case .item(let item):
                        ChatItemView(
                            item: item,
                            isPendingAskUser: item.id == pendingAskUser?.id,
                            isPendingApproval: item.id == pendingApproval?.id,
                            isPendingOnboard: item.id == pendingOnboard?.id,
                            isPendingPlanReview: item.id == pendingPlanReview?.id,
                            showAgentActions: item.kind == .agent && item.id != streamingMessageID,
                            isStreaming: item.id == streamingMessageID,
                            modelName: item.model ?? (item.id == lastAgentID ? responseModel : nil),
                            onAskUserResponse: onAskUserResponse,
                            onApprovalResponse: onApprovalResponse,
                            onOnboardSubmit: onOnboardSubmit,
                            onPlanReviewResponse: onPlanReviewResponse,
                            onRegenerate: { onRegenerate(item.id) },
                            onStreamComplete: { onStreamComplete(item.id) }
                        )
                        .id(unit.id)
                        .transition(AppMotion.messageTransition)

                    case .activityGroup(_, let activityItems, let durationMS):
                        AgentActivityGroup(items: activityItems, durationMS: durationMS)
                        .id(unit.id)
                        .transition(AppMotion.messageTransition)
                    }
                }

                // Identity-based positioning keeps this target visible while activity rows are
                // replaced and the final reply grows during its typewriter reveal.
                Color.clear
                    .frame(height: 1)
                    .id(transcriptBottomAnchorID)
            }
            .scrollTargetLayout()
            .frame(maxWidth: AppTheme.contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(.rect)
            // Tapping the transcript (anywhere not on an interactive control) dismisses the keyboard.
            .onTapGesture { dismissKeyboard() }
        }
        .accessibilityIdentifier(AccessibilityID.chatList)
        .scrollDismissesKeyboard(.interactively)
        // Keep a real view identity positioned instead of a calculated content edge. The latter can
        // become stale while optimistic rows are animated out and streamed rows are inserted.
        .scrollPosition($transcriptPosition, anchor: .bottom)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentSize.height - geometry.visibleRect.maxY <= 44
        } action: { _, nearBottom in
            isNearBottom = nearBottom
        }
        .onScrollPhaseChange { _, phase in
            switch phase {
            case .tracking, .interacting:
                followsTail = false
            case .idle:
                if isNearBottom {
                    followsTail = true
                }
            case .decelerating, .animating:
                break
            }
        }
        // A newly-sent message always starts a fresh turn at the bottom, even if the user had
        // previously inspected older messages.
        .onChange(of: newestUserID) { oldID, newID in
            guard let newID, newID != oldID else { return }
            followsTail = true
            scrollToTail()
        }
        .onChange(of: scrollUpdateToken) { _, _ in
            guard followsTail else { return }
            scrollToTail()
        }
        .onAppear {
            followsTail = true
            scrollToTail()
        }
    }

    private func scrollToTail() {
        transcriptPosition.scrollTo(id: transcriptBottomAnchorID, anchor: .bottom)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct ScrollUpdateToken: Equatable {
    var itemCount: Int
    var lastItemID: ChatItem.ID?
    var lastContentLength: Int
    var lastResultLength: Int
    var lastImageCount: Int
    var lastStatus: String?
    var lastAnswered: Bool
    var streamingMessageID: ChatItem.ID?
}

private extension ChatItemKind {
    var isPrimaryTimelineContent: Bool {
        switch self {
        case .user, .agent, .askUser, .approvalNeeded, .onboardRequired, .planReview:
            true
        case .thinking, .toolCall, .onboardSuccess, .intent, .evaluation, .compact,
             .toolBlocked, .filesReceived, .ulwTurnsReached, .unknown:
            false
        }
    }
}

#Preview("Chat Message List") {
    let items = [
        PreviewFixtures.sampleUserMessage,
        PreviewFixtures.sampleThinking,
        PreviewFixtures.sampleToolCall,
        PreviewFixtures.sampleAgentMessage,
        PreviewFixtures.sampleAskUser
    ]

    ChatMessageList(
        items: items,
        pendingAskUser: PreviewFixtures.sampleAskUser,
        pendingApproval: nil,
        pendingOnboard: nil,
        pendingPlanReview: nil,
        onAskUserResponse: { _ in },
        onApprovalResponse: { _, _, _, _ in },
        onOnboardSubmit: { _, _ in },
        onPlanReviewResponse: { _ in }
    )
}
