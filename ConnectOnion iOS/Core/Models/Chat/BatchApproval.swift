import Foundation

struct BatchApproval: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { tool + arguments }
    var tool: String
    var arguments: String
}
