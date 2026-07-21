//
//  AgentInput.swift
//
//  Purpose: Implements AgentInput for the Core/Network/Client module.
//  Collaborates with: ConnectOnionClient, ConnectOnionClientEvent, ConnectOnionClientProviding, MockConnectOnionClient, ProtocolCodec, ServerEvent.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
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
