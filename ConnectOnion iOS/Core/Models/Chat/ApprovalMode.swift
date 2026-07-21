//
//  ApprovalMode.swift
//
//  Purpose: Implements ApprovalMode for the Core/Models/Chat module.
//  Collaborates with: AskUserField, BatchApproval, ChatItem, ChatItemKind, ConversationSession, ExecutionStatus.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum ApprovalMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case safe
    case plan
    case acceptEdits = "accept_edits"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safe: "Safe"
        case .plan: "Plan"
        case .acceptEdits: "Accept Edits"
        }
    }
}
