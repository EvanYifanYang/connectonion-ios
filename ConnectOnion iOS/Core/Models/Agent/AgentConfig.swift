//
//  AgentConfig.swift
//
//  Purpose: Implements AgentConfig for the Core/Models/Agent module.
//  Collaborates with: AgentAcceptedInputs, AgentAddress, AgentInfo+Merging, AgentInfo, SkillInfo.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
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
