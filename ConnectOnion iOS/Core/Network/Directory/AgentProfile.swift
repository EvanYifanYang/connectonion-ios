//
//  AgentProfile.swift
//
//  Purpose: Implements AgentProfile for the Core/Network/Directory module.
//  Collaborates with: AgentDirectoryService, AgentDirectoryServicing, AgentRoute, DirectAgentInfo, MockAgentDirectoryService, RelayAgentRecord.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct AgentProfile: Codable, Equatable, Sendable {
    var address: String?
    var name: String?
    var alias: String?
    var tools: [ToolName]
    var skills: [SkillInfo]
    var trust: String?
    var version: String?
    var model: String?
    var balanceUSD: Double?
    var onboarding: AgentOnboardingOptions?
    var acceptedInputs: AgentAcceptedInputs?

    init(
        address: String? = nil,
        name: String? = nil,
        alias: String? = nil,
        tools: [ToolName] = [],
        skills: [SkillInfo] = [],
        trust: String? = nil,
        version: String? = nil,
        model: String? = nil,
        balanceUSD: Double? = nil,
        onboarding: AgentOnboardingOptions? = nil,
        acceptedInputs: AgentAcceptedInputs? = nil
    ) {
        self.address = address
        self.name = name
        self.alias = alias
        self.tools = tools
        self.skills = skills
        self.trust = trust
        self.version = version
        self.model = model
        self.balanceUSD = balanceUSD
        self.onboarding = onboarding
        self.acceptedInputs = acceptedInputs
    }

    enum CodingKeys: String, CodingKey {
        case address
        case name
        case alias
        case tools
        case skills
        case trust
        case version
        case model
        case balanceUSD = "balance_usd"
        case onboarding = "onboard"
        case acceptedInputs = "accepted_inputs"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
        tools = try container.decodeIfPresent([ToolName].self, forKey: .tools) ?? []
        skills = try container.decodeIfPresent([SkillInfo].self, forKey: .skills) ?? []
        trust = try container.decodeIfPresent(String.self, forKey: .trust)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        balanceUSD = try container.decodeIfPresent(Double.self, forKey: .balanceUSD)
        onboarding = try container.decodeIfPresent(AgentOnboardingOptions.self, forKey: .onboarding)
        acceptedInputs = try container.decodeIfPresent(AgentAcceptedInputs.self, forKey: .acceptedInputs)
    }
}
