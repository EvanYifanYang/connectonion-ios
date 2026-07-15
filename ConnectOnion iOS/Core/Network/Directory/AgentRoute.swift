import Foundation

enum AgentRoute: Equatable, Sendable {
    case direct(httpURL: URL, webSocketURL: URL)
    case relay(webSocketURL: URL)

    var webSocketURL: URL {
        switch self {
        case .direct(_, let webSocketURL), .relay(let webSocketURL):
            webSocketURL
        }
    }

    var isDirect: Bool {
        if case .direct = self { true } else { false }
    }
}
