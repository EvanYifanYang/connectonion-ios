import Foundation

@MainActor
protocol WebSocketTransporting: AnyObject {
    var isConnected: Bool { get }
    func connect(to url: URL) async throws
    func send(json: [String: JSONValue]) async throws
    func send(text: String) async throws
    func messages() -> AsyncThrowingStream<String, Error>
    func close()
}
