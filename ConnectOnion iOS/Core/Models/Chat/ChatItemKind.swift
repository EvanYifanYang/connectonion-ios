//
//  ChatItemKind.swift
//
//  Purpose: Implements ChatItemKind for the Core/Models/Chat module.
//  Collaborates with: ApprovalMode, AskUserField, BatchApproval, ChatItem, ConversationSession, ExecutionStatus.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum ChatItemKind: String, Codable, Hashable, Sendable {
    case user
    case agent
    case thinking
    case toolCall = "tool_call"
    case askUser = "ask_user"
    case approvalNeeded = "approval_needed"
    case onboardRequired = "onboard_required"
    case onboardSuccess = "onboard_success"
    case intent
    case evaluation = "eval"
    case compact
    case toolBlocked = "tool_blocked"
    case planReview = "plan_review"
    case filesReceived = "files_received"
    case ulwTurnsReached = "ulw_turns_reached"
    case unknown
}
