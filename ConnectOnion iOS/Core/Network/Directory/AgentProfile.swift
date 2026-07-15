import Foundation

struct AgentProfile: Codable, Equatable, Sendable {
    var name: String?
    var alias: String?
    var tools: [ToolName]
    var skills: [SkillInfo]
    var trust: String?
    var version: String?
    var model: String?
    var acceptedInputs: AgentAcceptedInputs?

    init(
        name: String? = nil,
        alias: String? = nil,
        tools: [ToolName] = [],
        skills: [SkillInfo] = [],
        trust: String? = nil,
        version: String? = nil,
        model: String? = nil,
        acceptedInputs: AgentAcceptedInputs? = nil
    ) {
        self.name = name
        self.alias = alias
        self.tools = tools
        self.skills = skills
        self.trust = trust
        self.version = version
        self.model = model
        self.acceptedInputs = acceptedInputs
    }

    enum CodingKeys: String, CodingKey {
        case name
        case alias
        case tools
        case skills
        case trust
        case version
        case model
        case acceptedInputs = "accepted_inputs"
    }
}
