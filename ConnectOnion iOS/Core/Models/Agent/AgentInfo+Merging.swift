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
        copy.acceptedInputs = profile.acceptedInputs ?? copy.acceptedInputs
        return copy
    }
}
