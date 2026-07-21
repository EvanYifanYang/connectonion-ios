//
//  ConnectOnionClient.swift
//
//  Purpose: Implements ConnectOnionClient for the Core/Network/Client module.
//  Collaborates with: AgentInput, ConnectOnionClientEvent, ConnectOnionClientProviding, MockConnectOnionClient, ProtocolCodec, ServerEvent.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import OSLog

@MainActor
final class ConnectOnionClient: ConnectOnionClientProviding {
    private let directory: AgentDirectoryServicing
    private let identityStore: IdentityProviding
    private let transportFactory: @MainActor () -> WebSocketTransporting

    private var transport: WebSocketTransporting?
    private var route: AgentRoute?
    private var codec: ProtocolCodec
    private let logger = Logger(subsystem: "com.romantcD.ConnectOnion-iOS", category: "AgentClient")

    init(
        directory: AgentDirectoryServicing = AgentDirectoryService(),
        identityStore: IdentityProviding = KeychainIdentityStore(),
        transportFactory: @escaping @MainActor () -> WebSocketTransporting = { WebSocketTransport() }
    ) {
        self.directory = directory
        self.identityStore = identityStore
        self.transportFactory = transportFactory
        codec = ProtocolCodec(identityStore: identityStore)
    }

    func send(input: AgentInput, to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let context = try await connect(agent: agent, session: session, continuation: continuation)
                    let message = try codec.inputMessage(
                        input: input,
                        agentAddress: agent.address,
                        route: context.route,
                        sessionID: session.remoteSessionID ?? session.id.uuidString
                    )
                    try await context.transport.send(text: encodedInputMessageText(message))
                    try await drainMessages(from: context.stream, continuation: continuation, finishOnIdle: true)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func reconnect(to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let context = try await connect(agent: agent, session: session, forceNewConnection: true, continuation: continuation)
                    try await drainMessages(from: context.stream, continuation: continuation, finishOnIdle: true)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func sendAskUserResponse(_ answer: String) async throws {
        try await activeTransport().send(json: codec.askUserResponse(answer))
    }

    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws {
        try await activeTransport().send(json: codec.approvalResponse(approved: approved, scope: scope, mode: mode, feedback: feedback))
    }

    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws {
        try await activeTransport().send(json: codec.onboardSubmit(inviteCode: inviteCode, payment: payment))
    }

    func sendPlanReviewResponse(_ message: String) async throws {
        try await activeTransport().send(json: codec.planReviewResponse(message: message))
    }

    func disconnect() {
        transport?.close()
        transport = nil
        route = nil
    }

    private func connect(
        agent: AgentConfig,
        session: ConversationSession,
        forceNewConnection: Bool = false,
        continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation
    ) async throws -> ConnectionContext {
        if forceNewConnection {
            disconnect()
        }

        let route = try await directory.resolveRoute(for: agent.address, preferredEndpoint: agent.preferredEndpoint)
        let transport = self.transport ?? transportFactory()
        self.transport = transport
        self.route = route

        if !transport.isConnected {
            try await transport.connect(to: route.webSocketURL)
        }

        let stream = transport.messages()
        try await transport.send(json: codec.connectMessage(agentAddress: agent.address, route: route, session: session))
        try await waitForConnected(on: stream, continuation: continuation)

        return ConnectionContext(transport: transport, route: route, stream: stream)
    }

    private func waitForConnected(
        on stream: AsyncThrowingStream<String, Error>,
        continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation
    ) async throws {
        for try await rawMessage in stream {
            let event = try codec.decode(rawMessage)

            if event.type == "PING" {
                try await transport?.send(json: ["type": .string("PONG")])
                continue
            }

            if event.type == "CONNECTED" {
                let connected = connectedEvent(from: event)
                continuation.yield(connected)
                return
            }

            continuation.yield(.server(event))
        }
    }

    private func drainMessages(
        from stream: AsyncThrowingStream<String, Error>,
        continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation,
        finishOnIdle: Bool
    ) async throws {
        for try await rawMessage in stream {
            let event: ServerEvent
            do {
                event = try codec.decode(rawMessage)
            } catch {
                logger.error("Ignoring malformed WebSocket event: \(error.localizedDescription, privacy: .public)")
                continue
            }

            if event.type == "PING" {
                try await transport?.send(json: ["type": .string("PONG")])
                continue
            }

            if event.type == "OUTPUT" {
                continuation.yield(outputEvent(from: event))
                if finishOnIdle {
                    continuation.finish()
                    return
                }
            } else if event.type == "ERROR" {
                let message = event.payload[string: "message"] ?? event.payload[string: "error"] ?? "Unknown agent error"
                continuation.yield(.failure(message))
                continuation.finish()
                return
            } else {
                continuation.yield(.server(event))
            }
        }
    }

    private func activeTransport() throws -> WebSocketTransporting {
        guard let transport, transport.isConnected else {
            throw URLError(.notConnectedToInternet)
        }
        return transport
    }

    private func encodedInputMessageText(_ message: [String: JSONValue]) throws -> String {
        let text = try message.jsonString()
        let size = text.utf8.count
        guard size <= AttachmentEncoding.defaultMaxInputFrameBytes else {
            throw ConnectOnionClientError.inputFrameTooLarge(
                size: size,
                maxSize: AttachmentEncoding.defaultMaxInputFrameBytes
            )
        }
        return text
    }

    private func connectedEvent(from event: ServerEvent) -> ConnectOnionClientEvent {
        let sessionValue = event.payload["session"]
        let chatItems = decodeChatItems(from: event.payload["chat_items"])
        return .connected(
            sessionID: event.payload[string: "session_id"] ?? "",
            status: event.payload[string: "status"] ?? "connected",
            serverNewer: event.payload[bool: "server_newer"] ?? false,
            session: sessionValue,
            chatItems: chatItems
        )
    }

    private func outputEvent(from event: ServerEvent) -> ConnectOnionClientEvent {
        .output(
            result: event.payload[string: "result"] ?? "",
            serverNewer: event.payload[bool: "server_newer"] ?? false,
            session: event.payload["session"],
            chatItems: decodeChatItems(from: event.payload["chat_items"])
        )
    }

    private func decodeChatItems(from value: JSONValue?) -> [ChatItem] {
        guard let values = value?.arrayValue else { return [] }

        return values.enumerated().compactMap { index, value in
            do {
                let data = try JSONEncoder().encode(value)
                let item = try JSONDecoder().decode(ChatItem.self, from: data)
                return AgentContentSanitizer.sanitize(item)
            } catch {
                logger.warning(
                    "Preserving malformed chat item at index \(index, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                var item = ChatItem(
                    id: value.objectValue?["id"]?.stringValue ?? UUID().uuidString,
                    kind: .unknown,
                    content: "Unsupported chat item"
                )
                item.eventType = value.objectValue?["type"]?.stringValue ?? "unknown"
                item.rawPayload = value.objectValue ?? ["value": value]
                return item
            }
        }
    }
}

private struct ConnectionContext {
    var transport: WebSocketTransporting
    var route: AgentRoute
    var stream: AsyncThrowingStream<String, Error>
}

private enum ConnectOnionClientError: LocalizedError {
    case inputFrameTooLarge(size: Int, maxSize: Int)

    var errorDescription: String? {
        switch self {
        case .inputFrameTooLarge(let size, let maxSize):
            "Message is too large to send (\(Self.format(size)) > \(Self.format(maxSize))). Remove an attachment or try a smaller file."
        }
    }

    private static func format(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }
        if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        }
        return String(format: "%.1f MB", Double(bytes) / Double(1024 * 1024))
    }
}
