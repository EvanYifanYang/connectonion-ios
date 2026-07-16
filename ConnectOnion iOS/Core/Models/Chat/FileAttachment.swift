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
