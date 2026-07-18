import Foundation

struct AgentInput: Equatable, Sendable {
    var prompt: String
    var customInstructions: String
    var personality: PersonalityMode
    var images: [String]
    var files: [FileAttachment]

    var transmittedPrompt: String {
        CustomInstructions.injecting(
            personality: personality,
            instructions: customInstructions,
            into: prompt
        )
    }

    init(
        prompt: String,
        customInstructions: String = "",
        personality: PersonalityMode = .pragmatic,
        images: [String] = [],
        files: [FileAttachment] = []
    ) {
        self.prompt = prompt
        self.customInstructions = CustomInstructions.normalized(customInstructions)
        self.personality = personality
        self.images = images
        self.files = files
    }
}
