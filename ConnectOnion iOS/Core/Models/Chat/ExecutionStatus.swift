//
//  ExecutionStatus.swift
//
//  Purpose: Implements ExecutionStatus for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, AskUserField, BatchApproval, ChatItem, ChatItemKind, ConversationSession.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum ExecutionStatus: String, Codable, Sendable {
    case running
    case done
    case error
    case analyzing
    case understood
    case evaluating
    case compacting
}
