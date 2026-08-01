//
//  ChatItemView.swift
//
//  Purpose: Implements ChatItemView for the Features/Chat module.
//  Collaborates with: ChatErrorBanner, ChatHeaderView, ChatMessageList, ChatScreen, ChatTimeline, ChatViewModel.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct ChatItemView: View {
    var item: ChatItem
    /// True when rendered inside an `AgentActivityGroup`'s expanded trace. Only `.agent` differs by
    /// context — an interim assistant message folds into a quiet step instead of a full bubble.
    var isInTrace: Bool = false
    var isPendingAskUser: Bool = false
    var isPendingApproval: Bool = false
    var isPendingOnboard: Bool = false
    var isPendingPlanReview: Bool = false
    var showAgentActions: Bool = false
    var modelName: String? = nil
    var onAskUserResponse: (String) -> Void = { _ in }
    var onApprovalResponse: (Bool, String, String?, String?) -> Void = { _, _, _, _ in }
    var onOnboardSubmit: (String?, Double?) -> Void = { _, _ in }
    var onPlanReviewResponse: (String) -> Void = { _ in }
    var onRegenerate: () -> Void = {}
    var isStreaming: Bool = false
    var onStreamComplete: () -> Void = {}

    var body: some View {
        switch item.kind {
        case .user:
            UserBubble(item: item)
        case .agent:
            if isInTrace {
                ActivityStepRow(step: item.activityStep ?? .fallback)
            } else {
                AgentBubble(
                    item: item,
                    showActions: showAgentActions,
                    isStreaming: isStreaming,
                    modelName: modelName,
                    onRegenerate: onRegenerate,
                    onStreamComplete: onStreamComplete
                )
            }
        case .askUser:
            AskUserCard(item: item, isPending: isPendingAskUser, onResponse: onAskUserResponse)
        case .approvalNeeded:
            ApprovalNeededCard(item: item, isPending: isPendingApproval, onResponse: onApprovalResponse)
        case .onboardRequired:
            OnboardRequiredCard(item: item, isPending: isPendingOnboard, onSubmit: onOnboardSubmit)
        case .planReview:
            PlanReviewCard(item: item, isPending: isPendingPlanReview, onResponse: onPlanReviewResponse)
        // Everything below is execution detail: it only ever appears inside an activity trace, and
        // renders as one uniform quiet step rather than its own tinted pill/card.
        case .thinking, .toolCall, .onboardSuccess, .intent, .evaluation, .compact,
             .toolBlocked, .filesReceived, .ulwTurnsReached, .unknown:
            ActivityStepRow(step: item.activityStep ?? .fallback)
        }
    }
}

#Preview("Chat Item Variety") {
    ChatItemViewPreview()
}

private struct ChatItemViewPreview: View {
    var body: some View {
    ScrollView {
        LazyVStack(spacing: 2) {
            previewItem(PreviewFixtures.sampleUserMessage)
            previewItem(PreviewFixtures.sampleAgentMessage)
            previewItem(PreviewFixtures.sampleThinking)
            previewItem(PreviewFixtures.sampleToolCall)
            previewItem(PreviewFixtures.sampleAskUser)
            previewItem(PreviewFixtures.sampleApproval)
            previewItem(PreviewFixtures.sampleOnboardRequired)
            previewItem(PreviewFixtures.sampleOnboardSuccess)
            previewItem(PreviewFixtures.sampleIntent)
            previewItem(PreviewFixtures.sampleEvaluation)
            previewItem(PreviewFixtures.sampleCompact)
            previewItem(PreviewFixtures.sampleToolBlocked)
            previewItem(PreviewFixtures.samplePlanReview)
            previewItem(PreviewFixtures.sampleFilesReceived)
        }
        .padding()
    }
    }

    private func previewItem(_ item: ChatItem) -> some View {
        ChatItemView(
            item: item,
            isPendingAskUser: item.kind == .askUser,
            isPendingApproval: item.kind == .approvalNeeded,
            isPendingOnboard: item.kind == .onboardRequired,
            isPendingPlanReview: item.kind == .planReview,
            onAskUserResponse: { _ in },
            onApprovalResponse: { _, _, _, _ in },
            onOnboardSubmit: { _, _ in },
            onPlanReviewResponse: { _ in }
        )
    }
}
