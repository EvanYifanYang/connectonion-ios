//
//  ChatMessageList.swift
//
//  Purpose: Implements ChatMessageList for the Features/Chat module.
//  Collaborates with: ChatErrorBanner, ChatHeaderView, ChatItemView, ChatScreen, ChatTimeline, ChatViewModel.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
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
    var responseModel: String?
    var isAgentRunning = false
    var streamingMessageID: ChatItem.ID?
    var onStreamComplete: (ChatItem.ID) -> Void = { _ in }

    @State private var isTailVisible = true
    @State private var followsTail = true
    @State private var scrollRequest = 0
    // ChatGPT-style "send pins the new prompt to the top, leaving room below for the reply".
    // While a turn is pinned we reserve a bottom gap sized to the viewport so the prompt can
    // actually reach the top, and we suppress tail-follow so the reply grows in below it.
    @State private var viewportHeight: CGFloat = 0
    @State private var topPinnedUserID: ChatItem.ID?
    @State private var topPinRequest = 0

    private var bottomReserveHeight: CGFloat {
        topPinnedUserID != nil ? max(12, viewportHeight - 140) : 12
    }

    private var lastAgentID: ChatItem.ID? {
        items.last { $0.kind == .agent }?.id
    }

    private var newestUserID: ChatItem.ID? {
        items.last { $0.kind == .user }?.id
    }

    // Pulled out of the ForEach body (and pre-computing the flags into locals) so the SwiftUI
    // type-checker doesn't time out on the ~19-argument ChatItemView call.
    @ViewBuilder
    private func itemRow(for item: ChatItem) -> some View {
        let isStreamingItem = item.id == streamingMessageID
        let showActions = item.kind == .agent && !isStreamingItem
        let model: String? = item.id == lastAgentID ? (item.model ?? responseModel) : nil
        ChatItemView(
            item: item,
            isPendingAskUser: item.id == pendingAskUser?.id,
            isPendingApproval: item.id == pendingApproval?.id,
            isPendingOnboard: item.id == pendingOnboard?.id,
            isPendingPlanReview: item.id == pendingPlanReview?.id,
            showAgentActions: showActions,
            modelName: model,
            onAskUserResponse: onAskUserResponse,
            onApprovalResponse: onApprovalResponse,
            onOnboardSubmit: onOnboardSubmit,
            onPlanReviewResponse: onPlanReviewResponse,
            onRegenerate: { onRegenerate(item.id) },
            isStreaming: isStreamingItem,
            onStreamComplete: { onStreamComplete(item.id) }
        )
    }

    var body: some View {
        let units = ChatTimelineBuilder.makeUnits(from: items)
        let tailID = units.last?.id
        let tailToken = TranscriptTailToken(
            unitCount: units.count,
            tailID: tailID,
            lastAnswered: items.last?.answered ?? false
        )

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(units) { unit in
                        switch unit.content {
                        case .item(let item):
                            itemRow(for: item)

                        case .activity(let activityItems, let durationMS):
                            AgentActivityGroup(
                                items: activityItems,
                                durationMS: durationMS,
                                isRunning: isAgentRunning && unit.id == tailID
                            )
                        }
                    }

                    Color.clear
                        .frame(height: bottomReserveHeight)
                        .id(transcriptBottomAnchorID)
                        .onScrollVisibilityChange(threshold: 0.1) { visible in
                            isTailVisible = visible
                            if visible {
                                followsTail = true
                            }
                        }
                }
                .frame(maxWidth: AppTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .contentShape(.rect)
                .onTapGesture { dismissKeyboard() }
            }
            // Restored conversations should open on the latest turn. Limiting this to the initial
            // offset preserves the user's manual scroll position for every interaction afterwards.
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .accessibilityIdentifier(AccessibilityID.chatList)
            .scrollDismissesKeyboard(.interactively)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .onScrollPhaseChange { _, phase in
                switch phase {
                case .tracking, .interacting:
                    followsTail = false
                case .idle:
                    if isTailVisible {
                        followsTail = true
                    }
                case .decelerating, .animating:
                    break
                }
            }
            .onChange(of: newestUserID) { oldID, newID in
                guard let newID, newID != oldID else { return }
                // Pin the just-sent prompt to the top and open the bottom reserve, rather than
                // following the tail — this leaves empty space for the incoming reply.
                followsTail = false
                topPinnedUserID = newID
                topPinRequest &+= 1
            }
            .onChange(of: tailToken) { _, _ in
                guard followsTail else { return }
                scrollRequest &+= 1
            }
            .onChange(of: isAgentRunning) { _, running in
                // Release the pinned turn when the reply finishes: the reserve collapses and
                // normal tail-follow resumes for subsequent turns.
                if !running { topPinnedUserID = nil }
            }
            .onAppear {
                followsTail = true
                scrollRequest &+= 1
            }
            .task(id: scrollRequest) {
                await Task.yield()
                guard !Task.isCancelled, followsTail, topPinnedUserID == nil else { return }
                proxy.scrollTo(transcriptBottomAnchorID, anchor: .bottom)
            }
            .task(id: topPinRequest) {
                guard topPinRequest > 0, let pinID = topPinnedUserID else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("item-\(pinID)", anchor: .top)
                }
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct TranscriptTailToken: Equatable {
    var unitCount: Int
    var tailID: String?
    var lastAnswered: Bool
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
