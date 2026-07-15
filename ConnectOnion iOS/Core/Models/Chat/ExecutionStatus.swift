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
