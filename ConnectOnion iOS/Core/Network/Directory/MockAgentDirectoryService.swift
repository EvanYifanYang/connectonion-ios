//
//  MockAgentDirectoryService.swift
//
//  Purpose: Implements MockAgentDirectoryService for the Core/Network/Directory module.
//  Collaborates with: AgentDirectoryService, AgentDirectoryServicing, AgentProfile, AgentRoute, DirectAgentInfo, RelayAgentRecord.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct MockAgentDirectoryService: AgentDirectoryServicing {
    var includesCapabilities = true

    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo {
        AgentInfo(
            address: address,
            name: "OpenOnion",
            tools: includesCapabilities
                ? ["bash", "read_file", "ask_user", "write_file", "search", "plan_review", "eval"]
                : [],
            skills: includesCapabilities
                ? [
                    SkillInfo(name: "summarize", description: "Summarize a document"),
                    SkillInfo(name: "research", description: "Research a topic"),
                    SkillInfo(name: "debug", description: "Debug an error"),
                    SkillInfo(name: "ship", description: "Prepare a release"),
                    SkillInfo(name: "audit", description: "Review a codebase"),
                    SkillInfo(name: "explain", description: "Explain a tricky file")
                ]
                : [],
            trust: "careful",
            version: "1.0",
            model: "co/gemini-2.5-flash",
            acceptedInputs: AgentAcceptedInputs(text: true, images: true, files: .init(maxFileSizeMB: 10, maxFilesPerRequest: 4)),
            online: true
        )
    }

    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute {
        .relay(webSocketURL: URL(string: "wss://oo.openonion.ai/ws/input")!)
    }
}
