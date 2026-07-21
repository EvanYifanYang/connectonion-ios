//
//  AskUserField.swift
//
//  Purpose: Implements AskUserField for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, BatchApproval, ChatItem, ChatItemKind, ConversationSession, ExecutionStatus.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct AskUserField: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var label: String
    var type: FieldType?
    var placeholder: String?
    var required: Bool?
    var autocomplete: String?
}

extension AskUserField {
    enum FieldType: String, Codable, Sendable {
        case text
        case password
    }
}
