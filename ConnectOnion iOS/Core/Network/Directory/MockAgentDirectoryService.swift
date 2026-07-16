import Foundation

struct MockAgentDirectoryService: AgentDirectoryServicing {
    func fetchAgentInfo(address: String) async -> AgentInfo {
        AgentInfo(
            address: address,
            name: "OpenOnion",
            tools: ["bash", "read_file", "ask_user", "write_plan"],
            skills: [
                SkillInfo(name: "summarize", description: "Summarize content"),
                SkillInfo(name: "debug", description: "Debug a problem")
            ],
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
