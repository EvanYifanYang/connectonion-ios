import Foundation

struct ServerEvent: Equatable, Sendable {
    var type: String
    var payload: [String: JSONValue]

    init(payload: [String: JSONValue]) {
        self.payload = payload
        type = payload[string: "type"] ?? ""
    }

    var id: String? {
        payload[string: "id"] ?? payload[string: "tool_id"]
    }
}
