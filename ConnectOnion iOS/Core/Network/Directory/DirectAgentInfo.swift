import Foundation

struct DirectAgentInfo: Decodable, Sendable {
    var address: String
    var profile: AgentProfile

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let object = try container.decode([String: JSONValue].self)

        address = object[string: "address"] ?? ""
        profile = AgentProfile(
            name: object[string: "name"],
            alias: object[string: "alias"],
            tools: (object["tools"]?.arrayValue ?? []).compactMap { value in
                if let string = value.stringValue { return ToolName.name(string) }
                if let name = value.objectValue?[string: "name"] { return ToolName.name(name) }
                return nil
            },
            skills: (try? object["skills"].map { try JSONDecoder().decode([SkillInfo].self, from: JSONEncoder().encode($0)) }) ?? [],
            trust: object[string: "trust"],
            version: object[string: "version"],
            model: object[string: "model"],
            acceptedInputs: try? object["accepted_inputs"].map {
                try JSONDecoder().decode(AgentAcceptedInputs.self, from: JSONEncoder().encode($0))
            }
        )
    }
}
