//
//  RelayAgentRecord.swift
//
//  Purpose: Implements RelayAgentRecord for the Core/Network/Directory module.
//  Collaborates with: AgentDirectoryService, AgentDirectoryServicing, AgentProfile, AgentRoute, DirectAgentInfo, MockAgentDirectoryService.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
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
