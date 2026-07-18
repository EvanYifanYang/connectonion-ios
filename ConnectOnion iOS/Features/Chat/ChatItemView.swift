import SwiftUI

struct ChatItemView: View {
    var item: ChatItem
    var isPendingAskUser: Bool
    var isPendingApproval: Bool
    var isPendingOnboard: Bool
    var isPendingPlanReview: Bool
    var showAgentActions: Bool = false
    var canEditUserMessage: Bool = false
    var isEditingUserMessage: Bool = false
    var isStreaming: Bool = false
    var modelName: String? = nil
    var onAskUserResponse: (String) -> Void
    var onApprovalResponse: (Bool, String, String?, String?) -> Void
    var onOnboardSubmit: (String?, Double?) -> Void
    var onPlanReviewResponse: (String) -> Void
    var onRegenerate: () -> Void = {}
    var onBeginUserEdit: () -> Void = {}
    var onCancelUserEdit: () -> Void = {}
    var onSaveUserEdit: (String) -> Bool = { _ in false }
    var onStreamComplete: () -> Void = {}

    var body: some View {
        switch item.kind {
        case .user:
            UserBubble(
                item: item,
                canEdit: canEditUserMessage,
                isEditing: isEditingUserMessage,
                onBeginEditing: onBeginUserEdit,
                onCancelEditing: onCancelUserEdit,
                onSaveEditing: onSaveUserEdit
            )
        case .agent:
            AgentBubble(
                item: item,
                showActions: showAgentActions,
                isStreaming: isStreaming,
                modelName: modelName,
                onRegenerate: onRegenerate,
                onStreamComplete: onStreamComplete
            )
        case .thinking:
            // Only show the thinking row while it's actively running (the peeling-onion animation) or
            // when it carries reasoning text. A finished, empty "model" row is redundant — the model
            // now appears as a footer under the reply.
            if item.status == .running || !item.content.isEmpty {
                ThinkingRow(item: item)
            }
        case .toolCall:
            ToolCallCard(item: item, isPendingApproval: isPendingApproval, onApprovalResponse: onApprovalResponse)
        case .askUser:
            AskUserCard(item: item, isPending: isPendingAskUser, onResponse: onAskUserResponse)
        case .approvalNeeded:
            ApprovalNeededCard(item: item, isPending: isPendingApproval, onResponse: onApprovalResponse)
        case .onboardRequired:
            OnboardRequiredCard(item: item, isPending: isPendingOnboard, onSubmit: onOnboardSubmit)
        case .onboardSuccess:
            StatusPill(systemImage: "checkmark.circle.fill", text: item.content, tint: .green)
        case .intent:
            IntentRow(item: item)
        case .evaluation:
            EvaluationRow(item: item)
        case .compact:
            CompactRow(item: item)
        case .toolBlocked:
            StatusPill(systemImage: "hand.raised.fill", text: item.content, tint: .orange)
        case .planReview:
            PlanReviewCard(item: item, isPending: isPendingPlanReview, onResponse: onPlanReviewResponse)
        case .filesReceived:
            FilesReceivedRow(item: item)
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
