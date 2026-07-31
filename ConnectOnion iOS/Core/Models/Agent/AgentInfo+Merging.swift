//
//  AgentInfo+Merging.swift
//
//  Purpose: Implements AgentInfo+Merging for the Core/Models/Agent module.
//  Collaborates with: AgentAcceptedInputs, AgentAddress, AgentConfig, AgentInfo, SkillInfo.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

extension AgentInfo {
    func merged(with directInfo: AgentInfo) -> AgentInfo {
        var copy = self
        copy.name = directInfo.name ?? copy.name
        if !directInfo.tools.isEmpty { copy.tools = directInfo.tools }
        if !directInfo.skills.isEmpty { copy.skills = directInfo.skills }
        copy.trust = directInfo.trust ?? copy.trust
        copy.version = directInfo.version ?? copy.version
        copy.model = directInfo.model ?? copy.model
        copy.balanceUSD = directInfo.balanceUSD ?? copy.balanceUSD
        copy.onboarding = directInfo.onboarding ?? copy.onboarding
        copy.acceptedInputs = directInfo.acceptedInputs ?? copy.acceptedInputs
        copy.online = directInfo.online || copy.online
        return copy
    }

    func merged(with profile: AgentProfile?) -> AgentInfo {
        guard let profile else { return self }

        var copy = self
        copy.name = profile.name ?? profile.alias ?? copy.name

        let tools = profile.tools.map(\.value).filter { !$0.isEmpty }
        if !tools.isEmpty {
            copy.tools = tools
        }

        if !profile.skills.isEmpty {
            copy.skills = profile.skills
        }

        copy.trust = profile.trust ?? copy.trust
        copy.version = profile.version ?? copy.version
        copy.model = profile.model ?? copy.model
        copy.balanceUSD = profile.balanceUSD ?? copy.balanceUSD
        copy.onboarding = profile.onboarding ?? copy.onboarding
        copy.acceptedInputs = profile.acceptedInputs ?? copy.acceptedInputs
        return copy
    }

    /// An AGENT_PROFILE frame is an authenticated snapshot, not the sparse public-directory patch
    /// represented by `merged(with:)`. Empty arrays mean the agent now has no capabilities, and an
    /// omitted balance means this agent has no managed-key balance to display.
    func merged(withAuthenticated profile: AgentProfile) -> AgentInfo {
        var copy = merged(with: profile)
        copy.tools = profile.tools.map(\.value).filter { !$0.isEmpty }
        copy.skills = profile.skills
        copy.balanceUSD = profile.balanceUSD
        return copy
    }
}
