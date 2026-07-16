import Foundation

struct SkillInfo: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var description: String
    var location: String?
}
