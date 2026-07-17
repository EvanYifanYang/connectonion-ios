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

        for item in items {
            if item.kind == .user {
                flushActivity()
                turnID = item.id
                activitySegment = 0
                units.append(itemUnit(item))
            } else if item.kind.isPrimaryTimelineContent {
                flushActivity(completedBy: item.kind == .agent ? item : nil)
                units.append(itemUnit(item))
            } else {
                activityItems.append(item)
            }
        }

        flushActivity()
        return units
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
