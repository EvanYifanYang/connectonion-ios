//
//  BatchApproval.swift
//
//  Purpose: Implements BatchApproval for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, AskUserField, ChatItem, ChatItemKind, ConversationSession, ExecutionStatus.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct BatchApproval: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { tool + arguments }
    var tool: String
    var arguments: String
}
