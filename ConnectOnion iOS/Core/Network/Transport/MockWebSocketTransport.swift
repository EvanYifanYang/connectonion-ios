import Foundation

@MainActor
final class MockWebSocketTransport: WebSocketTransporting {
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private(set) var sentMessages: [String] = []
    var scriptedMessages: [String]
    var isConnected = false

    init(scriptedMessages: [String] = []) {
        self.scriptedMessages = scriptedMessages
    }

    func connect(to url: URL) async throws {
        isConnected = true
    }

    func send(json: [String: JSONValue]) async throws {
        try await send(text: json.jsonString())
    }

    func send(text: String) async throws {
        sentMessages.append(text)
        for message in scriptedMessages {
            continuation?.yield(message)
        }
        scriptedMessages.removeAll()
    }

    func messages() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func close() {
        isConnected = false
        continuation?.finish()
    }
}
