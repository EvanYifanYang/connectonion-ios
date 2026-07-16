import Foundation

struct AgentConfig: Codable, Equatable, Identifiable, Sendable {
    var id: String { address }
    var address: String
    var alias: String
    var preferredEndpoint: URL?
    var createdAt: Date
    var lastConnectedAt: Date?

    var displayName: String {
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAlias.isEmpty {
            return trimmedAlias
        } else {
            return AgentAddress(rawValue: address)?.shortDisplay ?? address
        }
    }
}
