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
    var isGenerating: Bool = false
    var responseModel: String?

    private var lastAgentID: ChatItem.ID? {
        items.last { $0.kind == .agent }?.id
    }

    /// A run of consecutive tool calls renders as one grouped, collapsible card; everything else renders
    /// as its own item.
    private enum RenderUnit: Identifiable {
        case item(ChatItem)
        case toolGroup(id: String, items: [ChatItem])

        var id: String {
            switch self {
            case .item(let item): item.id
            case .toolGroup(let id, _): id
            }
        }
    }

    private var renderUnits: [RenderUnit] {
        var units: [RenderUnit] = []
        var group: [ChatItem] = []
        func flush() {
            guard !group.isEmpty else { return }
            units.append(.toolGroup(id: "tools-\(group[0].id)", items: group))
            group.removeAll()
        }
        for item in items {
            if item.kind == .toolCall {
                group.append(item)
            } else {
                flush()
                units.append(.item(item))
            }
        }
        flush()
        return units
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                                showAgentActions: item.id == lastAgentID && item.id != streamingMessageID && !isGenerating,
                                isStreaming: item.id == streamingMessageID,
                                modelName: item.id == lastAgentID ? responseModel : nil,
                                onAskUserResponse: onAskUserResponse,
                                onApprovalResponse: onApprovalResponse,
                                onOnboardSubmit: onOnboardSubmit,
                                onPlanReviewResponse: onPlanReviewResponse,
                                onRegenerate: onRegenerate,
                                onStreamComplete: { onStreamComplete(item.id) }
                            )
                            .id(unit.id)
                            .transition(AppMotion.messageTransition)

                        case .toolGroup(_, let toolItems):
                            ToolCallGroupCard(
                                items: toolItems,
                                pendingApprovalID: pendingApproval?.id,
                                onApprovalResponse: onApprovalResponse
                            )
                            .id(unit.id)
                            .transition(AppMotion.messageTransition)
                        }
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
            // The typewriter reveal grows a bubble's height without mutating `items`, so follow the
            // bottom while a reply streams in (the task auto-cancels when streaming clears).
            .task(id: streamingMessageID) {
                guard streamingMessageID != nil else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(50))
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
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
