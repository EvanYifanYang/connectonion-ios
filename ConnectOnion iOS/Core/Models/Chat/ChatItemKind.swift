import Foundation

enum ChatItemKind: String, Codable, Sendable {
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
}
