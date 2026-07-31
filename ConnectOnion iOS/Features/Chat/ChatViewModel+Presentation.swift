//
//  ChatViewModel+Presentation.swift
//
//  Purpose: Exposes presentation-only state derived from the chat session.
//
//  This file is part of the ConnectOnion iOS application.
//

extension ChatViewModel {
    var pendingAskUser: ChatItem? {
        items.last { $0.kind == .askUser && !$0.answered }
    }

    var pendingApproval: ChatItem? {
        items.last { $0.kind == .approvalNeeded && !$0.answered }
    }

    var pendingOnboard: ChatItem? {
        guard !items.contains(where: { $0.kind == .onboardSuccess }) else { return nil }
        return items.last { $0.kind == .onboardRequired && !$0.answered }
    }

    var pendingPlanReview: ChatItem? {
        items.last { $0.kind == .planReview && !$0.answered }
    }

    var hasPendingUserAction: Bool {
        pendingAskUser != nil ||
            pendingApproval != nil ||
            pendingOnboard != nil ||
            pendingPlanReview != nil
    }

    var shouldShowStopButton: Bool {
        (sessionState == .connecting || sessionState == .active || sessionState == .reconnecting)
            && !hasPendingUserAction
    }

    /// Context usage is cumulative for the conversation, so expose the latest known value at the
    /// conversation level instead of attaching it to an individual activity group in the UI.
    var contextPercent: Double? {
        items.reversed().compactMap(\.contextPercent).first
    }

    var isGeneratingReply: Bool {
        switch sessionState {
        case .connecting, .active, .reconnecting:
            true
        default:
            false
        }
    }

    var editableLatestUserMessageID: ChatItem.ID? {
        guard latestTurnCompleted,
              sessionState == .connected,
              !hasOngoingSession,
              streamingMessageID == nil,
              !hasPendingUserAction,
              errorMessage == nil,
              let lastUserIndex = items.lastIndex(where: { $0.kind == .user }),
              let lastAgentIndex = items.lastIndex(where: { $0.kind == .agent }),
              lastAgentIndex > lastUserIndex else {
            return nil
        }
        return items[lastUserIndex].id
    }
}
