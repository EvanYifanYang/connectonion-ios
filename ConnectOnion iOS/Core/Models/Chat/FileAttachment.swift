//
//  FileAttachment.swift
//
//  Purpose: Implements FileAttachment for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, AskUserField, BatchApproval, ChatItem, ChatItemKind, ConversationSession.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct FileAttachment: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var type: String
    var size: Int
    var dataURL: String

    init(id: String = UUID().uuidString, name: String, type: String, size: Int, dataURL: String) {
        self.id = id
        self.name = name
        self.type = type
        self.size = size
        self.dataURL = dataURL
    }
}
