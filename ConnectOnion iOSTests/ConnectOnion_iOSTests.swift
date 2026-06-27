import Foundation
import Testing
import UniformTypeIdentifiers
@testable import ConnectOnion_iOS

private let testAgentAddress = "0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"

struct AgentAddressTests {
    @Test func normalizesAndValidatesAgentAddresses() {
        let address = AgentAddress(rawValue: "  \(testAgentAddress.uppercased())  ")

        #expect(address?.rawValue == testAgentAddress)
        #expect(address?.shortDisplay == "0xf5ff04...dee1")
        #expect(AgentAddress.isValid(testAgentAddress))
        #expect(!AgentAddress.isValid("0x123"))
        #expect(!AgentAddress.isValid(String(repeating: "g", count: 66)))
    }
}

struct ProtocolCodecTests {
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

    @Test @MainActor func inputMessageCarriesAttachmentsAndSignedPayload() throws {
        let codec = ProtocolCodec(identityStore: MockIdentityStore())

        let message = try codec.inputMessage(
            input: AgentInput(
                prompt: "Inspect the project",
                images: ["data:image/png;base64,abc"],
                files: [
                    FileAttachment(
                        name: "README.md",
                        type: "text/markdown",
                        size: 6,
                        dataURL: "data:text/markdown;base64,cmVhZG1l"
                    )
                ]
            ),
            agentAddress: testAgentAddress,
            route: .relay(webSocketURL: URL(string: "wss://relay.example/ws/input")!)
        )

        #expect(message[string: "type"] == "INPUT")
        #expect(message[string: "prompt"] == "Inspect the project")
        #expect(message[string: "to"] == testAgentAddress)
        #expect(message[string: "from"]?.hasPrefix("0x") == true)
        #expect(message[string: "signature"]?.count == 128)
        #expect(message["images"]?.arrayValue?.count == 1)
        #expect(message["files"]?.arrayValue?.count == 1)

        let payload = message["payload"]?.objectValue
        #expect(payload?[string: "prompt"] == "Inspect the project")
        #expect(payload?[string: "to"] == testAgentAddress)
        #expect(payload?[int: "timestamp"] == message[int: "timestamp"])
    }
}

struct AttachmentEncodingTests {
    @Test func createsAndDecodesDataURLAttachments() throws {
        let data = try #require("readme".data(using: .utf8))
        let attachment = AttachmentEncoding.fileAttachment(
            name: "README.md",
            contentType: .markdown,
            data: data
        )

        #expect(attachment.name == "README.md")
        #expect(attachment.type == "text/markdown")
        #expect(attachment.size == data.count)
        #expect(attachment.dataURL.hasPrefix("data:text/markdown;base64,"))
        #expect(AttachmentEncoding.decodedData(from: attachment.dataURL) == data)
    }
}

struct ChatEventReducerTests {
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
}

struct ChatViewModelTests {
    @Test @MainActor func failedConnectionDoesNotEnterWorkingStateOrPersistOptimisticMessage() async throws {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: FailingConnectOnionClient())

        viewModel.send("Hello")

        #expect(viewModel.sessionState == .connecting)
        #expect(!viewModel.shouldShowStopButton)
        #expect(viewModel.items.isEmpty)
        #expect(conversation.messages.isEmpty)

        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.sessionState == .disconnected)
        #expect(!viewModel.shouldShowStopButton)
        #expect(viewModel.items.isEmpty)
        #expect(conversation.messages.isEmpty)
        #expect(viewModel.errorMessage?.contains("Could not connect") == true)
    }

    @Test @MainActor func firstPromptThatTriggersOnboardingResendsOriginalInputAfterInviteSuccess() async throws {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = OnboardFirstMessageClient()
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        viewModel.send("What can you do?")
        try await Task.sleep(for: .milliseconds(100))

        #expect(client.sentInputs.map(\.prompt) == ["What can you do?"])
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].kind == .onboardRequired)
        #expect(!viewModel.items.contains { $0.kind == .user })
        #expect(!conversation.messages.contains { $0.kind == .user })
        #expect(viewModel.pendingOnboard != nil)
        #expect(!viewModel.shouldShowFirstPromptSuggestions)

        viewModel.submitOnboard(inviteCode: "OpenOnion")
        try await Task.sleep(for: .milliseconds(150))

        #expect(viewModel.pendingOnboard == nil)
        #expect(!viewModel.shouldShowFirstPromptSuggestions)
        #expect(client.sentInputs.map(\.prompt) == ["What can you do?", "What can you do?"])
        #expect(conversation.messages.contains { $0.kind == .user && $0.content == "What can you do?" })
        #expect(conversation.title == "What can you do?")
    }

    @Test @MainActor func attachmentOnlyMessageSendsAndPersistsUserAttachments() async throws {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = AttachmentCapturingClient()
        let file = FileAttachment(
            id: "file-1",
            name: "README.md",
            type: "text/markdown",
            size: 6,
            dataURL: "data:text/markdown;base64,cmVhZG1l"
        )
        let image = "data:image/png;base64,aW1hZ2U="
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        viewModel.send("", images: [image], files: [file])
        try await Task.sleep(for: .milliseconds(100))

        #expect(client.sentInputs.count == 1)
        #expect(client.sentInputs.first?.prompt == "")
        #expect(client.sentInputs.first?.images == [image])
        #expect(client.sentInputs.first?.files == [file])
        #expect(viewModel.items.first?.kind == .user)
        #expect(viewModel.items.first?.images == [image])
        #expect(viewModel.items.first?.files == [file])
        #expect(conversation.messages.first?.images == [image])
        #expect(conversation.messages.first?.files == [file])
        #expect(conversation.title == "Image attachment")
    }
}

@MainActor
private final class FailingConnectOnionClient: ConnectOnionClientProviding {
    func send(input: AgentInput, to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: URLError(.cannotConnectToHost))
        }
    }

    func reconnect(to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        send(input: AgentInput(prompt: "Reconnect"), to: agent, session: session)
    }

    func sendAskUserResponse(_ answer: String) async throws {}
    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws {}
    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws {}
    func sendPlanReviewResponse(_ message: String) async throws {}
    func disconnect() {}
}

@MainActor
private final class OnboardFirstMessageClient: ConnectOnionClientProviding {
    private var continuation: AsyncThrowingStream<ConnectOnionClientEvent, Error>.Continuation?
    private var onboardAccepted = false
    private(set) var sentInputs: [AgentInput] = []

    func send(input: AgentInput, to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        sentInputs.append(input)
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            continuation.yield(.connected(sessionID: session.id.uuidString, status: "connected", serverNewer: false, session: nil, chatItems: []))

            if !onboardAccepted {
                continuation.yield(.server(ServerEvent(payload: [
                    "type": .string("RUNTIME_INPUT_ACK"),
                    "id": .string("input-ack")
                ])))
                continuation.yield(.server(ServerEvent(payload: [
                    "type": .string("ONBOARD_REQUIRED"),
                    "id": .string("onboard-first-message"),
                    "methods": .array([.string("invite_code")])
                ])))
                return
            }

            continuation.yield(.output(result: "Ready: \(input.prompt)", session: nil, chatItems: []))
            continuation.finish()
        }
    }

    func reconnect(to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        send(input: AgentInput(prompt: "Reconnect"), to: agent, session: session)
    }

    func sendAskUserResponse(_ answer: String) async throws {}
    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws {}
    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws {
        onboardAccepted = true
        continuation?.yield(.server(ServerEvent(payload: [
            "type": .string("ONBOARD_SUCCESS"),
            "id": .string("onboard-success"),
            "message": .string("Invite accepted")
        ])))
        continuation?.finish()
    }
    func sendPlanReviewResponse(_ message: String) async throws {}
    func disconnect() {}
}

@MainActor
private final class AttachmentCapturingClient: ConnectOnionClientProviding {
    private(set) var sentInputs: [AgentInput] = []

    func send(input: AgentInput, to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        sentInputs.append(input)
        return AsyncThrowingStream { continuation in
            continuation.yield(.connected(sessionID: session.id.uuidString, status: "connected", serverNewer: false, session: nil, chatItems: []))
            continuation.yield(.output(result: "Received attachments", session: nil, chatItems: []))
            continuation.finish()
        }
    }

    func reconnect(to agent: AgentConfig, session: ConversationSession) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        send(input: AgentInput(prompt: "Reconnect"), to: agent, session: session)
    }

    func sendAskUserResponse(_ answer: String) async throws {}
    func sendApprovalResponse(approved: Bool, scope: String, mode: String?, feedback: String?) async throws {}
    func sendOnboardSubmit(inviteCode: String?, payment: Double?) async throws {}
    func sendPlanReviewResponse(_ message: String) async throws {}
    func disconnect() {}
}
