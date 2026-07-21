//
//  ConversationSession.swift
//
//  Purpose: Implements ConversationSession for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, AskUserField, BatchApproval, ChatItem, ChatItemKind, ExecutionStatus.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct ConversationSession: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var agentAddress: String
    var remoteSessionID: String?
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var mode: ApprovalMode
    var messages: [ChatItem]
    var rawSession: JSONValue?
    var lastRenderedEventID: String?

    var protocolSessionObject: [String: JSONValue] {
        var object: [String: JSONValue] = [
            "session_id": .string(remoteSessionID ?? id.uuidString),
            "mode": .string(mode.rawValue),
            "messages": .array(messages.compactMap { item in
                switch item.kind {
                case .user:
                    .object(["role": .string("user"), "content": .string(item.content)])
                case .agent:
                    .object(["role": .string("assistant"), "content": .string(item.content)])
                default:
                    nil
                }
            })
        ]

        if let rawSession {
            object["raw"] = rawSession
        }

        return object
    }
}
