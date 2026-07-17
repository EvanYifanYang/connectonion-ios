import Foundation
import SwiftData

@Model
final class ConversationRecord {
    var id: UUID
    var agentAddress: String
    var remoteSessionID: String?
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modeRawValue: String
    var messagesData: Data
    var rawSessionData: Data?
    var lastRenderedEventID: String?
    /// Set when the user pins this chat to the top of the agent's list (most recent pin sorts first).
    var pinnedAt: Date?
    /// True when a reply completed while this conversation was not visible in the foreground.
    var hasUnread: Bool = false

    init(
        id: UUID = UUID(),
        agentAddress: String,
        remoteSessionID: String? = nil,
        title: String = "New chat",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        mode: ApprovalMode = .safe,
        messages: [ChatItem] = [],
        rawSession: JSONValue? = nil,
        lastRenderedEventID: String? = nil,
        hasUnread: Bool = false
    ) {
        self.id = id
        self.agentAddress = agentAddress
        self.remoteSessionID = remoteSessionID
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        modeRawValue = mode.rawValue
        messagesData = (try? JSONEncoder().encode(messages)) ?? Data()
        rawSessionData = try? JSONEncoder().encode(rawSession)
        self.lastRenderedEventID = lastRenderedEventID
        self.hasUnread = hasUnread
    }
}

extension ConversationRecord {
    var mode: ApprovalMode {
        get { ApprovalMode(rawValue: modeRawValue) ?? .safe }
        set {
            modeRawValue = newValue.rawValue
            updatedAt = .now
        }
    }

    var messages: [ChatItem] {
        get {
            guard !messagesData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([ChatItem].self, from: messagesData)) ?? []
        }
        set {
            messagesData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = .now
            updateTitleIfNeeded(from: newValue)
        }
    }

    var rawSession: JSONValue? {
        get {
            guard let rawSessionData else { return nil }
            return try? JSONDecoder().decode(JSONValue.self, from: rawSessionData)
        }
        set {
            rawSessionData = try? JSONEncoder().encode(newValue)
            updatedAt = .now
        }
    }

    var session: ConversationSession {
        ConversationSession(
            id: id,
            agentAddress: agentAddress,
            remoteSessionID: remoteSessionID,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            mode: mode,
            messages: messages,
            rawSession: rawSession,
            lastRenderedEventID: lastRenderedEventID
        )
    }

    func replace(with session: ConversationSession) {
        remoteSessionID = session.remoteSessionID
        title = session.title
        updatedAt = session.updatedAt
        mode = session.mode
        messages = session.messages
        rawSession = session.rawSession
        lastRenderedEventID = session.lastRenderedEventID
    }

    private func updateTitleIfNeeded(from messages: [ChatItem]) {
        guard title == "New chat" || title.isEmpty else { return }
        guard let firstUserMessage = messages.first(where: { $0.kind == .user }) else { return }
        let content = firstUserMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
            title = String(content.prefix(36))
        } else if !firstUserMessage.images.isEmpty {
            title = "Image attachment"
        } else if !firstUserMessage.files.isEmpty {
            title = "File attachment"
        }
    }
}
