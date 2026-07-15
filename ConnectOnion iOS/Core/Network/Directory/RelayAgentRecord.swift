import Foundation

struct RelayAgentRecord: Decodable, Sendable {
    var relay: String?
    var endpoints: [URL]
    var profile: AgentProfile?

    enum CodingKeys: String, CodingKey {
        case relay
        case endpoints
        case profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relay = try container.decodeIfPresent(String.self, forKey: .relay)
        let endpointStrings = try container.decodeIfPresent([String].self, forKey: .endpoints) ?? []
        endpoints = endpointStrings.compactMap(URL.init(string:))
        profile = try container.decodeIfPresent(AgentProfile.self, forKey: .profile)
    }
}
