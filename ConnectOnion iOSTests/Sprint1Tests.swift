//
//  Sprint1Tests.swift
//
//  Purpose: Implements Sprint1Tests for the ConnectOnion iOSTests module.
//  Collaborates with: AgentQRCodePayloadTests, AgentRoutingTests, ChatSessionStoreTests, CustomInstructionsTests, PersonalisationPreferencesTests, Sprint2Tests.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Testing
@testable import ConnectOnion_iOS

// MARK: - Sprint 1 — core deliverable
//
// Sprint 1 shipped the minimum end-to-end path: add an agent → connect (Ed25519
// handshake) → send a prompt → stream the agent's response back into the chat UI.
// These suites cover that path hermetically (no live agent); the live version is the
// XCUITest `ConnectOnion_iOSE2ETests`. Maps to proposal requirements R1 (connection),
// R2 (chat), R3 (streaming / execution feedback).

@Suite("Sprint 1 — Agent address (R1: add an agent)")
struct Sprint1AgentAddressTests {
    @Test func normalizesAndValidatesAgentAddresses() {
        let address = AgentAddress(rawValue: "  \(testAgentAddress.uppercased())  ")

        #expect(address?.rawValue == testAgentAddress)
        #expect(address?.shortDisplay == "0xf5ff04...dee1")
        #expect(AgentAddress.isValid(testAgentAddress))
        #expect(!AgentAddress.isValid("0x123"))
        #expect(!AgentAddress.isValid(String(repeating: "g", count: 66)))
    }
}

@Suite("Sprint 1 — Wire protocol (R1: signed CONNECT)")
struct Sprint1ProtocolTests {
    @Test @MainActor func connectMessageIncludesSignedEnvelopeAndSessionState() throws {
        let codec = ProtocolCodec(identityStore: MockIdentityStore())
        let session = ConversationSession(
            id: UUID(uuidString: "ECDBF683-072A-4C3F-A093-3295717F5C22")!,
            agentAddress: testAgentAddress,
            remoteSessionID: "remote-session-1",
            title: "Regression",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            mode: .plan,
            messages: [
                ChatItem(id: "user-1", kind: .user, content: "Hello"),
                ChatItem(id: "agent-1", kind: .agent, content: "Hi")
            ],
            rawSession: nil,
            lastRenderedEventID: "event-9"
        )

        let message = try codec.connectMessage(
            agentAddress: testAgentAddress,
            route: .relay(webSocketURL: URL(string: "wss://relay.example/ws/input")!),
            session: session
        )

        #expect(message[string: "type"] == "CONNECT")
        #expect(message[string: "session_id"] == "remote-session-1")
        #expect(message[string: "last_msg_id"] == "event-9")
        #expect(message[string: "to"] == testAgentAddress)
        #expect(message[string: "from"]?.hasPrefix("0x") == true)
        #expect(message[string: "signature"]?.count == 128)

        let payload = message["payload"]?.objectValue
        #expect(payload?[string: "to"] == testAgentAddress)

        let protocolSession = message["session"]?.objectValue
        #expect(protocolSession?[string: "mode"] == "plan")
        #expect(protocolSession?["messages"]?.arrayValue?.count == 2)
    }
}

@Suite("Sprint 1 — Streaming event handling (R3: execution feedback)")
struct Sprint1ChatEventTests {
    @Test func toolEventsAreMergedIntoOneRenderableCard() {
        var items: [ChatItem] = []

        let callState = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("tool_call"),
                "id": .string("tool-1"),
                "name": .string("read_file"),
                "args": .object(["path": .string("README.md")])
            ]),
            to: &items
        )

        let resultState = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("tool_result"),
                "id": .string("tool-1"),
                "status": .string("ok"),
                "result": .string("done"),
                "timing_ms": .number(42)
            ]),
            to: &items
        )

        #expect(callState == .active)
        #expect(resultState == .active)
        #expect(items.count == 1)
        #expect(items[0].kind == .toolCall)
        #expect(items[0].name == "read_file")
        #expect(items[0].status == .done)
        #expect(items[0].result == "done")
        #expect(items[0].timingMS == 42)
    }

    @Test func outOfOrderToolResultIsNotDroppedOrRegressedToRunning() {
        var items: [ChatItem] = []

        _ = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("tool_result"),
                "id": .string("tool-1"),
                "status": .string("ok"),
                "result": .string("done")
            ]),
            to: &items
        )
        _ = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("tool_call"),
                "id": .string("tool-1"),
                "name": .string("read_file"),
                "args": .object(["path": .string("README.md")])
            ]),
            to: &items
        )

        #expect(items.count == 1)
        #expect(items[0].name == "read_file")
        #expect(items[0].status == .done)
        #expect(items[0].result == "done")
    }

    @Test func askUserEventMovesSessionToWaitingAndStoresAnswer() {
        var items: [ChatItem] = []

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("ask_user"),
                "id": .string("ask-1"),
                "question": .string("Choose one"),
                "options": .array([.string("A"), .string("B")])
            ]),
            to: &items
        )

        ChatEventReducer.markLatestAskUserAnswered(answer: "A", in: &items)

        #expect(state == .waiting)
        #expect(items.count == 1)
        #expect(items[0].kind == .askUser)
        #expect(items[0].options == ["A", "B"])
        #expect(items[0].answered)
        #expect(items[0].answer == "A")
    }

    @Test func approvalResponseClearsPendingApproval() {
        var items: [ChatItem] = []

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("approval_needed"),
                "id": .string("approval-1"),
                "tool": .string("bash"),
                "description": .string("Search for SKILL.md")
            ]),
            to: &items
        )

        ChatEventReducer.markLatestApprovalAnswered(approved: true, scope: "once", mode: nil, in: &items)

        #expect(state == .waiting)
        #expect(items.count == 1)
        #expect(items[0].kind == .approvalNeeded)
        #expect(items[0].answered)
        #expect(items[0].answer == "Approved")
    }

    @Test func onboardSubmitClearsPendingVerification() {
        var items: [ChatItem] = []

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("ONBOARD_REQUIRED"),
                "id": .string("onboard-1"),
                "methods": .array([.string("invite_code")])
            ]),
            to: &items
        )

        ChatEventReducer.markLatestOnboardSubmitted(inviteCode: "OpenOnion", payment: nil, in: &items)

        #expect(state == .waiting)
        #expect(items.count == 1)
        #expect(items[0].kind == .onboardRequired)
        #expect(items[0].answered)
        #expect(items[0].answer == "Invite submitted")
    }

    @Test func onboardRejectionReopensCardWithErrorAndReturnsToWaiting() {
        var items: [ChatItem] = []

        _ = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("ONBOARD_REQUIRED"),
                "id": .string("onboard-1"),
                "methods": .array([.string("invite_code")])
            ]),
            to: &items
        )
        ChatEventReducer.markLatestOnboardSubmitted(inviteCode: "wrong-code", payment: nil, in: &items)
        #expect(items[0].answered)

        // ConnectOnion sends a generic ERROR for a rejected invite while leaving the pending CONNECT
        // alive. It must re-open the card, surface the reason, and leave the session waiting for retry.
        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("ERROR"),
                "message": .string("Invalid invite code")
            ]),
            to: &items
        )

        #expect(state == .waiting)
        #expect(items.count == 1)
        #expect(items[0].kind == .onboardRequired)
        #expect(!items[0].answered)
        #expect(items[0].answer == nil)
        #expect(items[0].reason == "Invalid invite code")
    }

    @Test func genericErrorWithoutPendingOnboardingDoesNotCreateOrReopenACard() {
        var items = [ChatItem(kind: .agent, content: "Earlier reply")]

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("ERROR"),
                "message": .string("Unrelated agent error")
            ]),
            to: &items
        )

        #expect(state == nil)
        #expect(items.count == 1)
        #expect(items[0].kind == .agent)
    }

    @Test func planReviewResponseClearsPendingReview() {
        var items: [ChatItem] = []

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("plan_review"),
                "id": .string("plan-1"),
                "plan_content": .string("1. Test\n2. Ship")
            ]),
            to: &items
        )

        ChatEventReducer.markLatestPlanReviewAnswered(message: "Plan needs revision.", in: &items)

        #expect(state == .waiting)
        #expect(items.count == 1)
        #expect(items[0].kind == .planReview)
        #expect(items[0].answered)
        #expect(items[0].answer == "Revision requested")
    }

    @Test func newerServerSnapshotPreservesAnsweredCardsAndUnsyncedLocalTurn() {
        var localApproval = ChatItem(id: "local-approval", kind: .approvalNeeded)
        localApproval.tool = "bash"
        localApproval.arguments = ["command": .string("pwd")]
        localApproval.answered = true
        localApproval.answer = "Approved"

        var localItems = [
            ChatItem(id: "local-user-1", kind: .user, content: "Inspect the project"),
            localApproval,
            ChatItem(id: "local-user-2", kind: .user, content: "Continue")
        ]

        var serverApproval = ChatItem(id: "server-approval", kind: .approvalNeeded)
        serverApproval.tool = "bash"
        serverApproval.arguments = ["command": .string("pwd")]
        let serverItems = [
            ChatItem(id: "server-user-1", kind: .user, content: "Inspect the project"),
            serverApproval
        ]

        ChatEventReducer.reconcile(with: serverItems, items: &localItems)

        #expect(localItems.count == 3)
        #expect(localItems[0].id == "local-user-1")
        #expect(localItems[1].id == "local-approval")
        #expect(localItems[1].answered)
        #expect(localItems[1].answer == "Approved")
        #expect(localItems[2].content == "Continue")
    }

    @Test func unknownEventIsPreservedInsteadOfBecomingAnAgentMessage() {
        var items: [ChatItem] = []

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("future_agent_event"),
                "id": .string("future-1"),
                "message": .string("A future event")
            ]),
            to: &items
        )

        #expect(state == nil)
        #expect(items.count == 1)
        #expect(items[0].kind == .unknown)
        #expect(items[0].eventType == "future_agent_event")
        #expect(items[0].content == "A future event")
        #expect(items[0].rawPayload[string: "type"] == "future_agent_event")
    }

    @Test func unknownStoredKindAndStatusDecodeLossily() throws {
        let data = Data(
            #"{"id":"future-1","type":"future_agent_event","status":"queued","message":"Still available"}"#.utf8
        )

        let item = try JSONDecoder().decode(ChatItem.self, from: data)

        #expect(item.kind == .unknown)
        #expect(item.eventType == "future_agent_event")
        #expect(item.status == nil)
        #expect(item.content == "Still available")
        #expect(item.rawPayload[string: "status"] == "queued")
    }

    @Test func ultraWorkLimitEventIsVisibleAndMovesSessionToWaiting() {
        var items: [ChatItem] = []

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("ulw_turns_reached"),
                "id": .string("ulw-1"),
                "turns_used": .number(12),
                "max_turns": .number(12)
            ]),
            to: &items
        )

        #expect(state == .waiting)
        #expect(items.count == 1)
        #expect(items[0].kind == .ulwTurnsReached)
        #expect(items[0].turnsUsed == 12)
        #expect(items[0].maxTurns == 12)
    }

    @Test func systemReminderIsRemovedWhileSurroundingAnswerIsPreserved() {
        let content = """
        Here is the answer.

        <SYSTEM-REMINDER>
        Internal agent instructions.
        </SYSTEM-REMINDER>

        ```python
        print("done")
        ```
        """

        let sanitized = AgentContentSanitizer.sanitize(content)

        #expect(sanitized.contains("Here is the answer."))
        #expect(sanitized.contains("print(\"done\")"))
        #expect(!sanitized.localizedCaseInsensitiveContains("system-reminder"))
        #expect(!sanitized.contains("Internal agent instructions"))
    }

    @Test func unterminatedSystemReminderIsRemovedThroughEndOfMessage() {
        let sanitized = AgentContentSanitizer.sanitize(
            "Visible answer\n<system-reminder>\nInternal instructions"
        )

        #expect(sanitized == "Visible answer")
    }

    @Test func reminderOnlyAssistantEventDoesNotCreateAnAgentBubble() {
        var items: [ChatItem] = []

        let state = ChatEventReducer.apply(
            ServerEvent(payload: [
                "type": .string("assistant"),
                "id": .string("assistant-1"),
                "content": .string("<system-reminder>Internal instructions</system-reminder>")
            ]),
            to: &items
        )

        #expect(state == nil)
        #expect(items.isEmpty)
    }
}

@Suite("Sprint 1 — Connection lifecycle (R2: chat round-trip)")
struct Sprint1ConnectionTests {
    /// Sprint-1 acceptance, offline: connect → prompt → streamed reply, mirroring the
    /// live `ConnectOnion_iOSE2ETests` but hermetic and CI-safe.
    @Test @MainActor func successfulPromptStreamsAgentReplyIntoChat() async throws {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = StreamingConnectOnionClient()
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        viewModel.send("What is 21 plus 21?")
        await waitUntil { viewModel.items.contains { $0.kind == .agent } }

        #expect(client.sentInputs.map(\.prompt) == ["What is 21 plus 21?"])
        #expect(viewModel.sessionState == .connected)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.items.contains { $0.kind == .user && $0.content == "What is 21 plus 21?" })
        #expect(viewModel.items.contains { $0.kind == .agent && $0.content == "Connected. Streaming mock response" })
        #expect(conversation.messages.contains { $0.kind == .agent })
    }

    @Test @MainActor func failedConnectionDoesNotEnterWorkingStateOrPersistOptimisticMessage() async throws {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: FailingConnectOnionClient())

        viewModel.send("Hello")

        // Synchronous: the optimistic message is held pending, not yet committed to the transcript.
        #expect(viewModel.sessionState == .connecting)
        #expect(!viewModel.shouldShowStopButton)
        #expect(viewModel.items.isEmpty)
        #expect(conversation.messages.isEmpty)

        await waitUntil { viewModel.sessionState == .disconnected }

        #expect(viewModel.sessionState == .disconnected)
        #expect(!viewModel.shouldShowStopButton)
        #expect(viewModel.items.isEmpty)
        #expect(conversation.messages.isEmpty)
        #expect(viewModel.errorMessage?.contains("Could not connect") == true)
    }
}
