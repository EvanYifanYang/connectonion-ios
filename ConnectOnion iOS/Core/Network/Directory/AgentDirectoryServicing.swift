import Foundation

protocol AgentDirectoryServicing: Sendable {
    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo
    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute
}
