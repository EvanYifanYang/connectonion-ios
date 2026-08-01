//
//  WebSocketTransport.swift
//
//  Purpose: Implements WebSocketTransport for the Core/Network/Transport module.
//  Collaborates with: MockWebSocketTransport, WebSocketTransporting.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
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
        // Large inbound frames — 2 MB dashboard snapshots, and CONNECTED/OUTPUT frames whose chat_items
        // echo an image-heavy history — exceed URLSessionWebSocketTask's 1 MiB default, which would make
        // receive() throw and tear the socket down (losing the reply). Raise the ceiling well past the
        // documented ~2 MB frames.
        task.maximumMessageSize = 16 * 1024 * 1024
        self.task = task
        task.resume()
    }

    func send(json: [String: JSONValue]) async throws {
        try await send(text: json.jsonString())
    }

    func send(text: String) async throws {
        guard let task else {
            // The socket is gone — that is a lost connection, not a device without internet.
            throw URLError(.networkConnectionLost)
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
