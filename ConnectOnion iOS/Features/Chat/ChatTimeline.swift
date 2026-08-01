//
//  ChatTimeline.swift
//
//  Purpose: Implements ChatTimeline for the Features/Chat module.
//  Collaborates with: ChatErrorBanner, ChatHeaderView, ChatItemView, ChatMessageList, ChatScreen, ChatViewModel.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

/// A stable, presentation-only unit in the chat transcript. Internal execution events are grouped by
/// user turn and segment, so replacing the optimistic placeholder with the first real server event
/// updates the existing row instead of deleting and reinserting it.
struct ChatTimelineUnit: Identifiable {
    enum Content {
        case item(ChatItem)
        case activity(items: [ChatItem], durationMS: Int?)
    }

    let id: String
    let content: Content
}

enum ChatTimelineBuilder {
    static func makeUnits(from items: [ChatItem]) -> [ChatTimelineUnit] {
        var units: [ChatTimelineUnit] = []
        var activityItems: [ChatItem] = []
        var turnID = "initial"
        var activitySegment = 0

        func flushActivity(completedBy reply: ChatItem? = nil) {
            guard !activityItems.isEmpty else { return }
            units.append(ChatTimelineUnit(
                id: "activity-\(turnID)-\(activitySegment)",
                content: .activity(items: activityItems, durationMS: reply?.durationMS)
            ))
            activityItems.removeAll(keepingCapacity: true)
            activitySegment += 1
        }

        let finalAgentIDs = Self.finalAgentIDs(in: items)

        for item in items {
            if item.kind == .user {
                flushActivity()
                turnID = item.id
                activitySegment = 0
                units.append(itemUnit(item))
            } else if item.kind == .agent {
                // Only a turn's final assistant message stays a prominent bubble; interim assistant
                // messages fold into the activity group, so each turn reads as one collapsible trace
                // plus one answer (matching ChatGPT/Claude-style transcripts).
                if finalAgentIDs.contains(item.id) {
                    flushActivity(completedBy: item)
                    units.append(itemUnit(item))
                } else {
                    activityItems.append(item)
                }
            } else if item.kind.isPrimaryTimelineContent {
                flushActivity()
                units.append(itemUnit(item))
            } else {
                activityItems.append(item)
            }
        }

        flushActivity()
        return units
    }

    /// The id of the final `.agent` message in each user-delimited turn — the answer that stays a
    /// prominent bubble. Earlier assistant messages in the same turn fold into the activity group.
    private static func finalAgentIDs(in items: [ChatItem]) -> Set<String> {
        var result: Set<String> = []
        var lastAgentID: String?
        for item in items {
            switch item.kind {
            // An interactive card ends a segment just like a user prompt does. Answering a card does
            // not append a `.user` item, so without this the assistant message the user already read
            // above the card would be retroactively demoted into the collapsed trace once the
            // post-card reply arrives.
            case .user, .askUser, .approvalNeeded, .onboardRequired, .planReview:
                if let lastAgentID { result.insert(lastAgentID) }
                lastAgentID = nil
            case .agent:
                lastAgentID = item.id
            default:
                break
            }
        }
        if let lastAgentID { result.insert(lastAgentID) }
        return result
    }

    private static func itemUnit(_ item: ChatItem) -> ChatTimelineUnit {
        ChatTimelineUnit(id: "item-\(item.id)", content: .item(item))
    }
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
