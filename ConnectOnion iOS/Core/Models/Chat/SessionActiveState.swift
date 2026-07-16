import Foundation

enum SessionActiveState: String, Codable, Sendable {
    case idle
    case connecting
    case connected
    case active
    case waiting
    case disconnected
    case reconnecting
}
