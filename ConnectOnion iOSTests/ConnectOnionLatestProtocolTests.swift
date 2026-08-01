//
//  ConnectOnionLatestProtocolTests.swift
//
//  Purpose: Pins the iOS client to the connectonion 1.5.3 WebSocket and /info contract.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Testing
@testable import ConnectOnion_iOS

@Suite("connectonion 1.5.3 compatibility")
struct ConnectOnionLatestProtocolTests {
    @Test("Latest /info fields decode while sparse relay profiles remain legal")
    func latestAndSparseProfilesDecode() throws {
        let directData = Data(
            """
            {
              "address": "\(testAgentAddress)",
              "name": "oo",
              "tools": ["bash"],
              "skills": [{"name":"project-skill","description":"Published","location":"project"}],
              "model": "co/latest",
              "balance_usd": 12.5,
              "onboard": {"invite_code": true, "payment": 4.0}
            }
            """.utf8
        )

        let direct = try JSONDecoder().decode(DirectAgentInfo.self, from: directData)
        #expect(direct.address == testAgentAddress)
        #expect(direct.profile.balanceUSD == 12.5)
        #expect(direct.profile.onboarding == AgentOnboardingOptions(inviteCode: true, payment: 4))
        #expect(direct.profile.skills.map(\.name) == ["project-skill"])

        let sparse = try JSONDecoder().decode(
            AgentProfile.self,
            from: Data(#"{"alias":"minimal"}"#.utf8)
        )
        #expect(sparse.alias == "minimal")
        #expect(sparse.tools.isEmpty)
        #expect(sparse.skills.isEmpty)
    }

    @Test("Authenticated full profile survives an older public probe")
    @MainActor
    func authenticatedProfileRemainsAuthoritative() async {
        let publicInfo = AgentInfo(
            address: testAgentAddress,
            name: "oo",
            tools: ["bash"],
            skills: [
                SkillInfo(name: "project-skill", description: "Published", location: "project")
            ],
            online: true
        )
        let store = AgentInfoStore(
            directory: DelayedPublishedProfileDirectory(info: publicInfo, delay: .milliseconds(100))
        )

        let staleProbe = Task { @MainActor in
            await store.refreshNow(addresses: [testAgentAddress])
        }
        await waitUntil { store.isRefreshing }

        let authenticated = AgentProfile(
            address: testAgentAddress,
            name: "oo",
            tools: [.name("bash"), .name("read_file")],
            skills: [
                SkillInfo(name: "project-skill", description: "Published", location: "project"),
                SkillInfo(name: "private-skill", description: "Authenticated", location: "user")
            ],
            model: "co/latest",
            balanceUSD: 12.5
        )
        store.mergeAuthenticatedProfile(authenticated, for: testAgentAddress)
        await staleProbe.value

        let merged = store.infoByAddress[testAgentAddress]
        #expect(merged?.tools == ["bash", "read_file"])
        #expect(merged?.skills.map(\.name) == ["project-skill", "private-skill"])
        #expect(merged?.balanceUSD == 12.5)
        #expect(merged?.online == true)

        store.mergeAuthenticatedProfile(
            AgentProfile(
                address: testAgentAddress,
                name: "oo",
                tools: [],
                skills: [],
                model: "co/latest",
                balanceUSD: nil
            ),
            for: testAgentAddress
        )
        await store.refreshNow(addresses: [testAgentAddress])

        let cleared = store.infoByAddress[testAgentAddress]
        #expect(cleared?.tools.isEmpty == true)
        #expect(cleared?.skills.isEmpty == true)
        #expect(cleared?.balanceUSD == nil)
    }

    @Test("Metadata and passive control frames stay out of the chat event stream")
    @MainActor
    func latestFramesAreRoutedByPurpose() async throws {
        let transport = MockWebSocketTransport(scriptedMessages: [
            try frame([
                "type": .string("CONNECTED"),
                "session_id": .string("latest-session"),
                "status": .string("new")
            ]),
            try frame([
                "type": .string("AGENT_PROFILE"),
                "address": .string("0x" + String(repeating: "0", count: 64)),
                "name": .string("wrong")
            ]),
            try frame([
                "type": .string("AGENT_PROFILE"),
                "address": .string(testAgentAddress),
                "name": .string("oo"),
                "tools": .array([.string("bash"), .string("read_file")]),
                "skills": .array([
                    .object([
                        "name": .string("private-skill"),
                        "description": .string("Authenticated"),
                        "location": .string("user")
                    ])
                ]),
                "balance_usd": .number(12.5)
            ]),
            try frame([
                "type": .string("DASHBOARD_SNAPSHOT"),
                "html": .string("<h1>Not a chat message</h1>")
            ]),
            try frame([
                "type": .string("user_input"),
                "content": .string("Hello")
            ]),
            try frame([
                "type": .string("session_sync"),
                "session": .object(["mode": .string("safe")])
            ]),
            try frame([
                "type": .string("mode_changed"),
                "mode": .string("plan")
            ]),
            try frame([
                "type": .string("OUTPUT"),
                "result": .string("Done"),
                "duration_ms": .number(321)
            ])
        ])
        let client = ConnectOnionClient(
            directory: LatestProtocolRouteDirectory(),
            identityStore: MockIdentityStore(),
            transportFactory: { transport }
        )

        var events: [ConnectOnionClientEvent] = []
        for try await event in client.send(
            input: AgentInput(prompt: "Hello"),
            to: latestAgentConfig,
            session: latestConversationSession
        ) {
            events.append(event)
        }

        // CONNECTED, .inputSent (emitted once the INPUT frame leaves the device, so a retry knows
        // whether re-sending is safe), the profile, the routed control frame, and OUTPUT.
        #expect(events.count == 6)
        #expect(events.contains { if case .inputSent = $0 { true } else { false } })
        #expect(events.contains { event in
            guard case .profile(let profile) = event else { return false }
            return profile.address == testAgentAddress
                && profile.skills.map(\.name) == ["private-skill"]
                && profile.balanceUSD == 12.5
        })
        #expect(events.filter {
            if case .control = $0 { true } else { false }
        }.count == 2)
        #expect(!events.contains {
            if case .server = $0 { true } else { false }
        })
        #expect(events.contains {
            guard case .output(let result, let durationMS, _, _, _) = $0 else { return false }
            return result == "Done" && durationMS == 321
        })
    }

    @Test("A rejected CONNECT terminates instead of waiting forever")
    @MainActor
    func rejectedConnectFinishesPromptly() async throws {
        let transport = MockWebSocketTransport(scriptedMessages: [
            try frame([
                "type": .string("ERROR"),
                "message": .string("Invalid signature")
            ])
        ])
        let client = ConnectOnionClient(
            directory: LatestProtocolRouteDirectory(),
            identityStore: MockIdentityStore(),
            transportFactory: { transport }
        )

        var errorMessage: String?
        do {
            for try await _ in client.send(
                input: AgentInput(prompt: "Hello"),
                to: latestAgentConfig,
                session: latestConversationSession
            ) {}
        } catch {
            errorMessage = error.localizedDescription
        }

        #expect(errorMessage == "Invalid signature")
    }

    @Test("Onboarding rejection can retry, while a blocked identity is terminal")
    @MainActor
    func onboardingErrorsHaveExplicitLifetimes() async throws {
        let retryTransport = MockWebSocketTransport(scriptedMessages: [
            try frame([
                "type": .string("ONBOARD_REQUIRED"),
                "methods": .array([.string("invite_code")])
            ]),
            try frame([
                "type": .string("ERROR"),
                "message": .string("Invalid invite code")
            ]),
            try frame([
                "type": .string("ONBOARD_SUCCESS"),
                "message": .string("Invite code verified")
            ]),
            try frame([
                "type": .string("CONNECTED"),
                "session_id": .string("onboarded-session"),
                "status": .string("new")
            ]),
            try frame([
                "type": .string("OUTPUT"),
                "result": .string("Ready"),
                "duration_ms": .number(10)
            ])
        ])
        let retryClient = ConnectOnionClient(
            directory: LatestProtocolRouteDirectory(),
            identityStore: MockIdentityStore(),
            transportFactory: { retryTransport }
        )

        var retryEvents: [ConnectOnionClientEvent] = []
        for try await event in retryClient.send(
            input: AgentInput(prompt: "Hello"),
            to: latestAgentConfig,
            session: latestConversationSession
        ) {
            retryEvents.append(event)
        }
        #expect(retryEvents.contains {
            guard case .server(let event) = $0 else { return false }
            return event.type == "ERROR" && event.payload[string: "message"] == "Invalid invite code"
        })
        #expect(retryEvents.contains {
            guard case .output(let result, _, _, _, _) = $0 else { return false }
            return result == "Ready"
        })

        let blockedTransport = MockWebSocketTransport(scriptedMessages: [
            try frame([
                "type": .string("ONBOARD_REQUIRED"),
                "methods": .array([.string("invite_code")])
            ]),
            try frame([
                "type": .string("ERROR"),
                "message": .string("forbidden: blocked")
            ])
        ])
        let blockedClient = ConnectOnionClient(
            directory: LatestProtocolRouteDirectory(),
            identityStore: MockIdentityStore(),
            transportFactory: { blockedTransport }
        )

        var blockedError: String?
        do {
            for try await _ in blockedClient.send(
                input: AgentInput(prompt: "Hello"),
                to: latestAgentConfig,
                session: latestConversationSession
            ) {}
        } catch {
            blockedError = error.localizedDescription
        }
        #expect(blockedError == "forbidden: blocked")
    }

    @Test("Idle reconnect consumes the profile and then settles without OUTPUT")
    @MainActor
    func idleReconnectSettlesAfterMetadata() async throws {
        let transport = MockWebSocketTransport(scriptedMessages: [
            try frame([
                "type": .string("CONNECTED"),
                "session_id": .string("idle-session"),
                "status": .string("connected")
            ]),
            try frame([
                "type": .string("AGENT_PROFILE"),
                "address": .string(testAgentAddress),
                "name": .string("oo"),
                "tools": .array([.string("bash")]),
                "skills": .array([])
            ]),
            try frame([
                "type": .string("DASHBOARD_SNAPSHOT"),
                "html": .string("<h1>Idle</h1>")
            ])
        ])
        let client = ConnectOnionClient(
            directory: LatestProtocolRouteDirectory(),
            identityStore: MockIdentityStore(),
            transportFactory: { transport }
        )

        var events: [ConnectOnionClientEvent] = []
        for try await event in client.reconnect(
            to: latestAgentConfig,
            session: latestConversationSession
        ) {
            events.append(event)
        }

        #expect(events.count == 2)
        #expect(events.contains {
            guard case .profile(let profile) = $0 else { return false }
            return profile.address == testAgentAddress && profile.tools.map(\.value) == ["bash"]
        })
    }

    @Test("Settled reconnect releases the composer for the next send")
    @MainActor
    func settledReconnectAllowsNextMessage() async {
        let conversation = ConversationRecord(
            agentAddress: testAgentAddress,
            remoteSessionID: "idle-session",
            messages: [
                ChatItem(id: "prior-user", kind: .user, content: "Earlier"),
                ChatItem(id: "prior-agent", kind: .agent, content: "Finished")
            ]
        )
        let client = SettledReconnectClient()
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: latestAgentConfig,
            client: client
        )

        viewModel.reconnect()
        await waitUntil {
            client.reconnectCount == 1 && !viewModel.hasOngoingSession
        }

        #expect(viewModel.sessionState == .connected)
        viewModel.send("Next message")
        await waitUntil { client.sendCount == 1 }
        #expect(client.sentPrompts == ["Next message"])
    }

    @Test("Persisted intent and evaluation frames cannot regress terminal state")
    func terminalCoAIEventsRemainTerminal() {
        var items: [ChatItem] = []

        _ = ChatEventReducer.apply(ServerEvent(payload: [
            "type": .string("intent"),
            "id": .string("intent-1"),
            "status": .string("analyzing")
        ]), to: &items)
        _ = ChatEventReducer.apply(ServerEvent(payload: [
            "type": .string("intent"),
            "id": .string("intent-1"),
            "status": .string("understood"),
            "ack": .string("I understand"),
            "is_build": .bool(true)
        ]), to: &items)
        _ = ChatEventReducer.apply(ServerEvent(payload: [
            "type": .string("intent"),
            "id": .string("intent-1"),
            "ack": .string("I understand"),
            "is_build": .bool(true)
        ]), to: &items)

        _ = ChatEventReducer.apply(ServerEvent(payload: [
            "type": .string("eval"),
            "id": .string("eval-1"),
            "status": .string("evaluating")
        ]), to: &items)
        _ = ChatEventReducer.apply(ServerEvent(payload: [
            "type": .string("eval"),
            "id": .string("eval-1"),
            "status": .string("done"),
            "passed": .bool(true),
            "summary": .string("Complete")
        ]), to: &items)
        _ = ChatEventReducer.apply(ServerEvent(payload: [
            "type": .string("eval"),
            "id": .string("eval-1"),
            "passed": .bool(true),
            "summary": .string("Complete")
        ]), to: &items)

        #expect(items.first { $0.id == "intent-1" }?.status == .understood)
        #expect(items.first { $0.id == "intent-1" }?.ack == "I understand")
        #expect(items.first { $0.id == "eval-1" }?.status == .done)
        #expect(items.first { $0.id == "eval-1" }?.passed == true)
    }

    @Test("Passive controls update session state without clearing optimistic activity")
    @MainActor
    func passiveControlsDoNotAcknowledgeTheTurn() async {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let client = PassiveControlClient()
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: latestAgentConfig,
            client: client
        )

        viewModel.send("Keep working")
        await waitUntil {
            conversation.mode == .plan && conversation.rawSession != nil
        }

        #expect(viewModel.sessionState == .active)
        #expect(viewModel.items.contains {
            $0.id == "__optimistic__" && $0.kind == .thinking && $0.status == .running
        })
        #expect(!viewModel.items.contains { $0.kind == .unknown })
        #expect(conversation.rawSession == .object(["checkpoint": .string("latest")]))
        viewModel.stop()
    }
}

private let latestAgentConfig = AgentConfig(
    address: testAgentAddress,
    alias: "oo",
    preferredEndpoint: nil,
    createdAt: Date(timeIntervalSince1970: 0),
    lastConnectedAt: nil
)

private let latestConversationSession = ConversationSession(
    id: UUID(uuidString: "F5FF043A-9C5D-495E-AC93-87908DEA87BE")!,
    agentAddress: testAgentAddress,
    remoteSessionID: nil,
    title: "Latest protocol",
    createdAt: Date(timeIntervalSince1970: 0),
    updatedAt: Date(timeIntervalSince1970: 0),
    mode: .safe,
    messages: [],
    rawSession: nil,
    lastRenderedEventID: nil
)

private func frame(_ payload: [String: JSONValue]) throws -> String {
    try payload.jsonString()
}

private struct LatestProtocolRouteDirectory: AgentDirectoryServicing {
    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo {
        AgentInfo(address: address, online: true)
    }

    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute {
        .direct(
            httpURL: URL(string: "http://127.0.0.1:8000")!,
            webSocketURL: URL(string: "ws://127.0.0.1:8000/ws")!
        )
    }
}

private struct DelayedPublishedProfileDirectory: AgentDirectoryServicing {
    var info: AgentInfo
    var delay: Duration

    func fetchAgentInfo(address: String, preferredEndpoint: URL?) async -> AgentInfo {
        try? await Task.sleep(for: delay)
        return info
    }

    func resolveRoute(for address: String, preferredEndpoint: URL?) async throws -> AgentRoute {
        .relay(webSocketURL: URL(string: "wss://example.com/ws/input")!)
    }
}

@MainActor
private final class PassiveControlClient: ConnectOnionClientProviding {
    private var continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation?

    func send(
        input: AgentInput,
        to agent: AgentConfig,
        session: ConversationSession
    ) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            continuation.yield(.connected(
                sessionID: session.id.uuidString,
                status: "connected",
                serverNewer: false,
                session: nil,
                chatItems: []
            ))
            continuation.yield(.control(ServerEvent(payload: [
                "type": .string("session_sync"),
                "session": .object(["checkpoint": .string("latest")])
            ])))
            continuation.yield(.control(ServerEvent(payload: [
                "type": .string("mode_changed"),
                "mode": .string("plan")
            ])))
        }
    }

    func reconnect(
        to agent: AgentConfig,
        session: ConversationSession
    ) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func sendAskUserResponse(_ answer: String) async throws {}
    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws {}
    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws {}
    func sendPlanReviewResponse(_ message: String) async throws {}

    func disconnect() {
        continuation?.finish()
        continuation = nil
    }
}

@MainActor
private final class SettledReconnectClient: ConnectOnionClientProviding {
    private(set) var reconnectCount = 0
    private(set) var sendCount = 0
    private(set) var sentPrompts: [String] = []

    func send(
        input: AgentInput,
        to agent: AgentConfig,
        session: ConversationSession
    ) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        sendCount += 1
        sentPrompts.append(input.prompt)
        return AsyncThrowingStream { continuation in
            continuation.yield(.connected(
                sessionID: session.remoteSessionID ?? session.id.uuidString,
                status: "connected",
                serverNewer: false,
                session: nil,
                chatItems: []
            ))
            continuation.yield(.output(
                result: "Ready",
                durationMS: 10,
                serverNewer: false,
                session: nil,
                chatItems: []
            ))
            continuation.finish()
        }
    }

    func reconnect(
        to agent: AgentConfig,
        session: ConversationSession
    ) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        reconnectCount += 1
        return AsyncThrowingStream { continuation in
            continuation.yield(.connected(
                sessionID: session.remoteSessionID ?? session.id.uuidString,
                status: "connected",
                serverNewer: false,
                session: nil,
                chatItems: []
            ))
            continuation.finish()
        }
    }

    func sendAskUserResponse(_ answer: String) async throws {}
    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws {}
    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws {}
    func sendPlanReviewResponse(_ message: String) async throws {}
    func disconnect() {}
}
