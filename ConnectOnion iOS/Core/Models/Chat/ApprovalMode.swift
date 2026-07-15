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
