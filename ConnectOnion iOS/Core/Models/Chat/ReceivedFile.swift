//
//  ReceivedFile.swift
//
//  Purpose: Implements ReceivedFile for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, AskUserField, BatchApproval, ChatItem, ChatItemKind, ConversationSession.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct ReceivedFile: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { path }
    var name: String
    var path: String
}
