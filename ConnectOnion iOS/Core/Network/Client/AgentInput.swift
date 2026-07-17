import Foundation

struct AgentInput: Equatable, Sendable {
    var prompt: String
    var customInstructions: String
    var images: [String]
    var files: [FileAttachment]

    var transmittedPrompt: String {
        CustomInstructions.injecting(customInstructions, into: prompt)
    }

    init(
        prompt: String,
        customInstructions: String = "",
        images: [String] = [],
        files: [FileAttachment] = []
    ) {
        self.prompt = prompt
        self.customInstructions = CustomInstructions.normalized(customInstructions)
        self.images = images
        self.files = files
    }
}
