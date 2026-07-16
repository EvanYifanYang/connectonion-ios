import SwiftUI
import UIKit

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
    var onRegenerate: () -> Void = {}
    var streamingMessageID: ChatItem.ID?
    var onStreamComplete: (ChatItem.ID) -> Void = { _ in }

    private var lastAgentID: ChatItem.ID? {
        items.last { $0.kind == .agent }?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(items) { item in
                        ChatItemView(
                            item: item,
                            isPendingAskUser: item.id == pendingAskUser?.id,
                            isPendingApproval: item.id == pendingApproval?.id,
                            isPendingOnboard: item.id == pendingOnboard?.id,
                            isPendingPlanReview: item.id == pendingPlanReview?.id,
                            showAgentActions: item.id == lastAgentID && item.id != streamingMessageID,
                            isStreaming: item.id == streamingMessageID,
                            onAskUserResponse: onAskUserResponse,
                            onApprovalResponse: onApprovalResponse,
                            onOnboardSubmit: onOnboardSubmit,
                            onPlanReviewResponse: onPlanReviewResponse,
                            onRegenerate: onRegenerate,
                            onStreamComplete: { onStreamComplete(item.id) }
                        )
                        .id(item.id)
                        .transition(AppMotion.messageTransition)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .frame(maxWidth: AppTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .animation(AppMotion.standard, value: items.map(\.id))
                .contentShape(.rect)
                // Tapping the transcript (anywhere not on an interactive control) dismisses the keyboard.
                .onTapGesture { dismissKeyboard() }
            }
            .accessibilityIdentifier(AccessibilityID.chatList)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: items) { _, _ in
                withAnimation(.smooth(duration: 0.22)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .task {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
