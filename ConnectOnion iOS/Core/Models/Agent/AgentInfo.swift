import Foundation

struct AgentInfo: Codable, Equatable, Sendable {
    var address: String
    var name: String?
    var tools: [String]
    var skills: [SkillInfo]
    var trust: String?
    var version: String?
    var model: String?
    var acceptedInputs: AgentAcceptedInputs?
    var online: Bool

    init(
        address: String,
        name: String? = nil,
        tools: [String] = [],
        skills: [SkillInfo] = [],
        trust: String? = nil,
        version: String? = nil,
        model: String? = nil,
        acceptedInputs: AgentAcceptedInputs? = nil,
        online: Bool = false
    ) {
        self.address = address
        self.name = name
        self.tools = tools
        self.skills = skills
        self.trust = trust
        self.version = version
        self.model = model
        self.acceptedInputs = acceptedInputs
        self.online = online
    }

    enum CodingKeys: String, CodingKey {
        case address
        case name
        case tools
        case skills
        case trust
        case version
        case model
        case acceptedInputs = "accepted_inputs"
        case online
    }
}
