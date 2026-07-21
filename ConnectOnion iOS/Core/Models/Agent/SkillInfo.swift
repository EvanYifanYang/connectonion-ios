//
//  SkillInfo.swift
//
//  Purpose: Implements SkillInfo for the Core/Models/Agent module.
//  Collaborates with: AgentAcceptedInputs, AgentAddress, AgentConfig, AgentInfo+Merging, AgentInfo.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

struct SkillInfo: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var description: String
    var location: String?
}
