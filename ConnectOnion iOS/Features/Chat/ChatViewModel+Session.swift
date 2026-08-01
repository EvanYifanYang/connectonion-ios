//
//  ChatViewModel+Session.swift
//
//  Purpose: Builds the ConversationSession payloads the CONNECT handshake carries.
//  Collaborates with: ChatViewModel, ConversationSession, ProtocolCodec.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

extension ChatViewModel {
    func snapshot(excludingUserItemID: ChatItem.ID? = nil) -> ConversationSession {
        ConversationSession(
            id: conversation.id,
            agentAddress: conversation.agentAddress,
            remoteSessionID: conversation.remoteSessionID,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            mode: conversation.mode,
            messages: items.filter {
                $0.id != "__optimistic__" && $0.id != excludingUserItemID
            },
            // Read through the pending slot so CONNECT always carries the newest raw session even
            // when the debounced persist has not flushed it yet.
            rawSession: pendingRawSession ?? conversation.rawSession,
            lastRenderedEventID: conversation.lastRenderedEventID
        )
    }

    /// Regeneration is a replacement branch, not another input on the existing remote session.
    /// Carry the retained local history into a fresh session and omit cursors/raw state that point
    /// at the exchange being replaced.
    func replacementSnapshot(
        sessionID: String,
        excludingUserItemID: ChatItem.ID? = nil
    ) -> ConversationSession {
        var session = snapshot(excludingUserItemID: excludingUserItemID)
        session.remoteSessionID = sessionID
        session.rawSession = nil
        session.lastRenderedEventID = nil
        return session
    }
}
