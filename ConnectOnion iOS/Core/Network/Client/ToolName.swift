import Foundation

enum ToolName: Codable, Equatable, Hashable, Sendable {
    case name(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .name(value)
            return
        }

        let object = try container.decode([String: JSONValue].self)
        self = .name(object[string: "name"] ?? "")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .name(let value):
            try container.encode(value)
        }
    }

    var value: String {
        switch self {
        case .name(let value):
            value
        }
    }
}
