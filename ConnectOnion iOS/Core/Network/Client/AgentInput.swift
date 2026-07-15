import Foundation

struct AgentInput: Equatable, Sendable {
    var prompt: String
    var images: [String]
    var files: [FileAttachment]

    init(prompt: String, images: [String] = [], files: [FileAttachment] = []) {
        self.prompt = prompt
        self.images = images
        self.files = files
    }
}
