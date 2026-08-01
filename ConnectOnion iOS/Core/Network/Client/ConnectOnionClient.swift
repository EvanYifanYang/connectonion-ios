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
    /// True once the handshake has pushed a chat-visible event to the consumer. A re-probe after a
    /// stale cached route must not replay those into the reducer, so it is only safe while false.
    private var didYieldChatEventDuringHandshake = false
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
            let producerTask = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    let context = try await connect(agent: agent, session: session, continuation: continuation)
                    let message = try codec.inputMessage(
                        input: input,
                        agentAddress: agent.address,
                        route: context.route,
                        sessionID: session.remoteSessionID ?? session.id.uuidString
                    )
                    try await context.transport.send(text: encodedInputMessageText(message))
                    try await drainMessages(
                        from: context.stream,
                        expectedAgentAddress: context.agentAddress,
                        continuation: continuation,
                        finishOnIdle: true
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                producerTask.cancel()
            }
        }
    }

    func reconnect(to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        AsyncThrowingStream { continuation in
            let producerTask = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    let context = try await connect(agent: agent, session: session, forceNewConnection: true, continuation: continuation)
                    if context.status == "running" {
                        try await drainMessages(
                            from: context.stream,
                            expectedAgentAddress: context.agentAddress,
                            continuation: continuation,
                            finishOnIdle: true
                        )
                    } else {
                        // A 1.5.3 host emits no OUTPUT when a reconnected session is already idle.
                        // Consume its immediately-following authenticated profile before settling;
                        // older hosts have no profile, so the bounded fallback closes this idle
                        // connection instead of waiting forever.
                        await drainIdleConnectionMetadata(
                            from: context.stream,
                            expectedAgentAddress: context.agentAddress,
                            continuation: continuation
                        )
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                producerTask.cancel()
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
        allowRouteRetry: Bool = true,
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
        let status: String
        didYieldChatEventDuringHandshake = false
        do {
            try await transport.send(json: codec.connectMessage(agentAddress: agent.address, route: route, session: session))
            status = try await waitForConnected(
                on: stream,
                expectedAgentAddress: agent.address,
                continuation: continuation
            )
        } catch {
            // A cached route can go stale (the agent moved networks, the LAN endpoint died). Without a
            // re-probe the user would just see a failure, because a cache hit skips resolveRoute's own
            // direct → advertised → relay fallback chain. Drop the entry and run the full probe once.
            if error is CancellationError { throw error }
            if case ConnectOnionClientError.connectionRejected = error { throw error } // protocol-level, not routing
            await directory.invalidateRoute(for: agent.address)
            guard allowRouteRetry, !didYieldChatEventDuringHandshake else { throw error }
            logger.info("Handshake failed on the cached route — re-probing once")
            return try await connect(
                agent: agent,
                session: session,
                forceNewConnection: true,
                allowRouteRetry: false,
                continuation: continuation
            )
        }

        return ConnectionContext(
            transport: transport,
            route: route,
            stream: stream,
            agentAddress: agent.address,
            status: status
        )
    }

    private func waitForConnected(
        on stream: AsyncThrowingStream<String, Error>,
        expectedAgentAddress: String,
        continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation
    ) async throws -> String {
        var isAwaitingOnboarding = false

        for try await rawMessage in stream {
            let event = try codec.decode(rawMessage)

            if event.type == "PING" {
                try await transport?.send(json: ["type": .string("PONG")])
                continue
            }

            if consumeMetadataEvent(
                event,
                expectedAgentAddress: expectedAgentAddress,
                continuation: continuation
            ) {
                continue
            }

            if event.type == "CONNECTED" {
                let connected = connectedEvent(from: event)
                continuation.yield(connected)
                return event.payload[string: "status"] ?? "connected"
            }

            if event.type == "ONBOARD_REQUIRED" {
                isAwaitingOnboarding = true
                didYieldChatEventDuringHandshake = true
                continuation.yield(.server(event))
                continue
            }

            // A trust-gated onboarding flow keeps this socket alive so the user can submit another
            // invite/payment attempt. Every other pre-CONNECTED ERROR is terminal (invalid signature,
            // blacklist, malformed CONNECT, and so on); treating it as a chat event leaves the send
            // task waiting forever for a CONNECTED frame that the host will never send.
            if event.type == "ONBOARD_SUCCESS" {
                isAwaitingOnboarding = false
            }

            if event.type == "ERROR" {
                let message = event.payload[string: "message"]
                    ?? event.payload[string: "error"]
                    ?? "The agent rejected the connection."
                if isAwaitingOnboarding, Self.isRetryableOnboardingError(message) {
                    didYieldChatEventDuringHandshake = true
                    continuation.yield(.server(event))
                    continue
                }
                throw ConnectOnionClientError.connectionRejected(message)
            }

            didYieldChatEventDuringHandshake = true
            continuation.yield(.server(event))
        }

        throw URLError(.networkConnectionLost)
    }

    private func drainMessages(
        from stream: AsyncThrowingStream<String, Error>,
        expectedAgentAddress: String,
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

            if consumeMetadataEvent(
                event,
                expectedAgentAddress: expectedAgentAddress,
                continuation: continuation
            ) {
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

        throw URLError(.networkConnectionLost)
    }

    private func drainIdleConnectionMetadata(
        from stream: AsyncThrowingStream<String, Error>,
        expectedAgentAddress: String,
        continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation
    ) async {
        let timeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            self?.transport?.close()
        }
        defer { timeoutTask.cancel() }

        do {
            for try await rawMessage in stream {
                let event = try codec.decode(rawMessage)

                if event.type == "PING" {
                    try await transport?.send(json: ["type": .string("PONG")])
                    continue
                }

                let wasProfile = event.type == "AGENT_PROFILE"
                if consumeMetadataEvent(
                    event,
                    expectedAgentAddress: expectedAgentAddress,
                    continuation: continuation
                ) {
                    if wasProfile { return }
                    continue
                }

                if event.type == "ERROR" {
                    let message = event.payload[string: "message"]
                        ?? event.payload[string: "error"]
                        ?? "Unknown agent error"
                    continuation.yield(.failure(message))
                    return
                }

                continuation.yield(.server(event))
            }
        } catch is CancellationError {
            return
        } catch {
            logger.debug(
                "Idle reconnect metadata window ended: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// connectonion 1.5.3 sends authenticated profile and dashboard frames immediately after
    /// CONNECTED. They are connection metadata, not timeline events: routing them through the chat
    /// reducer creates duplicate/unknown bubbles and can persist up to 2 MB of dashboard HTML.
    private func consumeMetadataEvent(
        _ event: ServerEvent,
        expectedAgentAddress: String,
        continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation
    ) -> Bool {
        switch event.type {
        case "AGENT_PROFILE":
            do {
                let data = try JSONEncoder().encode(event.payload)
                let profile = try JSONDecoder().decode(AgentProfile.self, from: data)
                guard profile.address == nil || profile.address == expectedAgentAddress else {
                    logger.warning(
                        "Ignoring AGENT_PROFILE for an unexpected address: \(profile.address ?? "", privacy: .public)"
                    )
                    return true
                }
                continuation.yield(.profile(profile))
            } catch {
                logger.warning(
                    "Ignoring malformed AGENT_PROFILE: \(error.localizedDescription, privacy: .public)"
                )
            }
            return true

        case "session_sync", "SESSION_MERGED", "mode_changed", "RECONNECTED":
            continuation.yield(.control(event))
            return true

        case "DASHBOARD_SNAPSHOT", "user_input", "SESSION_STATUS":
            return true

        default:
            return false
        }
    }

    private func activeTransport() throws -> WebSocketTransporting {
        guard let transport, transport.isConnected else {
            throw URLError(.notConnectedToInternet)
        }
        return transport
    }

    private static func isRetryableOnboardingError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("invalid invite code")
            || normalized.contains("insufficient payment")
            || normalized.contains("invite_code or payment required")
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
            durationMS: event.payload[int: "duration_ms"],
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
    var agentAddress: String
    var status: String
}

private enum ConnectOnionClientError: LocalizedError {
    case connectionRejected(String)
    case inputFrameTooLarge(size: Int, maxSize: Int)

    var errorDescription: String? {
        switch self {
        case .connectionRejected(let message):
            message
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
