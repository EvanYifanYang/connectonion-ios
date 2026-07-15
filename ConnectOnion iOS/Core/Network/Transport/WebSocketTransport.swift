import Foundation

@MainActor
final class WebSocketTransport: WebSocketTransporting {
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    var isConnected: Bool {
        task != nil
    }

    func connect(to url: URL) async throws {
        close()
        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()
    }

    func send(json: [String: JSONValue]) async throws {
        try await send(text: json.jsonString())
    }

    func send(text: String) async throws {
        guard let task else {
            throw URLError(.notConnectedToInternet)
        }

        try await task.send(.string(text))
    }

    func messages() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            receiveTask?.cancel()
            receiveTask = Task { [weak self] in
                await self?.receiveLoop()
            }
        }
    }

    func close() {
        receiveTask?.cancel()
        receiveTask = nil
        continuation?.finish()
        continuation = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let task else {
                continuation?.finish()
                return
            }

            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    continuation?.yield(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        continuation?.yield(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                self.task = nil
                continuation?.finish(throwing: error)
                return
            }
        }
    }
}
