import Foundation

enum ConnectOnionClientEvent: Equatable, Sendable {
    case connected(sessionID: String, status: String, serverNewer: Bool, session: JSONValue?, chatItems: [ChatItem])
    case server(ServerEvent)
    case output(result: String, serverNewer: Bool, session: JSONValue?, chatItems: [ChatItem])
    case failure(String)
}
