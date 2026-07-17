import Foundation
import Observation

/// App-owned chat sessions. Keeping the view models here lets an in-flight reply continue after its
/// chat screen leaves the navigation stack, while still giving every conversation its own stream.
@MainActor
@Observable
final class ChatSessionStore {
    @ObservationIgnored private var sessions: [UUID: ChatViewModel] = [:]

    private(set) var visibleConversationID: UUID?

    func viewModel(
        for conversation: ConversationRecord,
        agent: AgentConfig,
        client: ConnectOnionClientProviding? = nil
    ) -> ChatViewModel {
        if let existing = sessions[conversation.id] {
            return existing
        }

        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent,
            client: client,
            onReplyCompleted: { [weak self] conversation in
                self?.replyCompleted(for: conversation)
            }
        )
        sessions[conversation.id] = viewModel
        return viewModel
    }

    func isGeneratingReply(for conversationID: UUID) -> Bool {
        sessions[conversationID]?.isGeneratingReply ?? false
    }

    /// The shell owns visibility because it can distinguish a foreground chat from the same view
    /// remaining mounted while the app is inactive.
    func setVisibleConversation(id: UUID?, conversation: ConversationRecord?) {
        visibleConversationID = id
        guard conversation?.id == id else { return }
        conversation?.hasUnread = false
    }

    /// Used when deleting a conversation (or its agent), so an owned stream is stopped before its
    /// SwiftData record disappears.
    func removeSession(for conversationID: UUID) {
        if let session = sessions[conversationID], session.hasOngoingSession {
            session.stop()
        }
        sessions[conversationID] = nil
        if visibleConversationID == conversationID {
            visibleConversationID = nil
        }
    }

    private func replyCompleted(for conversation: ConversationRecord) {
        let wasVisible = visibleConversationID == conversation.id
        conversation.hasUnread = !wasVisible

        // A reply that finished off-screen should already be fully rendered when the user opens it.
        if !wasVisible {
            sessions[conversation.id]?.streamingMessageID = nil
        }
    }
}
