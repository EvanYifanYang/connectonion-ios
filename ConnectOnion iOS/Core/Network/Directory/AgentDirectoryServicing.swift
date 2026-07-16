import Foundation

protocol AgentDirectoryServicing: Sendable {
    func fetchAgentInfo(address: String) async -> AgentInfo
    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute
}
