import Foundation

struct ReceivedFile: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { path }
    var name: String
    var path: String
}
