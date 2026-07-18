import Foundation
import Testing
@testable import ConnectOnion_iOS

@Suite("Custom instructions — prompt formatting")
struct CustomInstructionsFormattingTests {
    @Test func personalityIsInjectedEvenWithoutCustomInstructions() {
        let prompt = "Explain this"
        let transmitted = CustomInstructions.injecting(
            personality: .pragmatic,
            instructions: "  \n",
            into: prompt
        )

        #expect(transmitted.contains("concise, direct, task-focused"))
        #expect(CustomInstructions.removingWrapper(from: transmitted) == prompt)
    }

    @Test func multilineUnicodeInstructionsRoundTripToOriginalPrompt() {
        let instructions = """
        回答は日本語で。
        Keep examples concise. 🌱
        """
        let prompt = "Explain actor isolation\nwith an example."
        let transmitted = CustomInstructions.injecting(instructions, into: prompt)

        #expect(transmitted.contains("回答は日本語で。"))
        #expect(transmitted.contains("Keep examples concise. 🌱"))
        #expect(CustomInstructions.removingWrapper(from: transmitted) == prompt)
    }

    @Test func attachmentOnlyPromptRoundTripsAsEmpty() {
        let transmitted = CustomInstructions.injecting("Describe attached files", into: "")

        #expect(!transmitted.isEmpty)
        #expect(CustomInstructions.removingWrapper(from: transmitted) == "")
    }

    @Test func unwrappedAndMalformedPromptsAreNotChanged() {
        let plain = "A normal user request"
        let malformed = "<<<CONNECTONION_CUSTOM_INSTRUCTIONS_V1>>>\nMissing the remaining markers"
        let legacy = """
        <<<CONNECTONION_CUSTOM_INSTRUCTIONS_V1>>>
        Legacy preference
        <<<CONNECTONION_END_CUSTOM_INSTRUCTIONS_V1>>>

        <<<CONNECTONION_USER_REQUEST_V1>>>
        Original request
        """

        #expect(CustomInstructions.removingWrapper(from: plain) == plain)
        #expect(CustomInstructions.removingWrapper(from: malformed) == malformed)
        #expect(CustomInstructions.removingWrapper(from: legacy) == "Original request")
    }

    @Test func leadingSystemRemindersAreRemovedFromVisiblePrompts() {
        let reminder = """
        <system-reminder>
        Hidden agent-building instructions
        </system-reminder>
        """
        let wrapped = CustomInstructions.injecting(
            personality: .friendly,
            instructions: "Use short examples",
            into: "Explain recursion"
        )

        #expect(CustomInstructions.visiblePrompt(from: reminder) == "")
        #expect(CustomInstructions.visiblePrompt(from: "\(reminder)\n\nExplain recursion") == "Explain recursion")
        #expect(CustomInstructions.visiblePrompt(from: "\(reminder)\n\n\(wrapped)") == "Explain recursion")
        #expect(CustomInstructions.visiblePrompt(from: "\(reminder)\n\n\(reminder)\n\nExplain recursion") == "Explain recursion")
    }

    @Test func malformedAndInlineSystemReminderTextIsPreserved() {
        let malformed = "<system-reminder>Missing its closing tag"
        let inline = "Show the literal text <system-reminder> in an example"

        #expect(CustomInstructions.visiblePrompt(from: malformed) == malformed)
        #expect(CustomInstructions.visiblePrompt(from: inline) == inline)
    }
}

@Suite("Custom instructions — transport and lifecycle")
struct CustomInstructionsTransportTests {
    @Test @MainActor func codecUsesSameTransmittedPromptAtTopLevelAndInSignedPayload() throws {
        let codec = ProtocolCodec(identityStore: MockIdentityStore())
        let input = AgentInput(
            prompt: "Inspect the project",
            customInstructions: "Be concise",
            personality: .friendly
        )

        let message = try codec.inputMessage(
            input: input,
            agentAddress: testAgentAddress,
            route: .relay(webSocketURL: URL(string: "wss://relay.example/ws/input")!)
        )

        #expect(input.prompt == "Inspect the project")
        #expect(input.personality == .friendly)
        #expect(input.transmittedPrompt.contains("warm, collaborative"))
        #expect(input.transmittedPrompt != input.prompt)
        #expect(message[string: "prompt"] == input.transmittedPrompt)
        #expect(message["payload"]?.objectValue?[string: "prompt"] == input.transmittedPrompt)
    }

    @Test @MainActor func regenerateCapturesLatestSavedInstructions() async {
        var savedInstructions = "Use the first preference"
        var savedPersonality = PersonalityMode.pragmatic
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = StreamingConnectOnionClient(replyText: "Done")
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent.config,
            client: client,
            customInstructionsProvider: { savedInstructions },
            personalityProvider: { savedPersonality }
        )

        viewModel.send("Explain this")
        await waitUntil { client.sentInputs.count == 1 && viewModel.sessionState == .connected }
        savedInstructions = "Use the latest preference"
        savedPersonality = .friendly
        viewModel.regenerate()
        await waitUntil { client.sentInputs.count == 2 && viewModel.sessionState == .connected }

        #expect(client.sentInputs.map(\.prompt) == ["Explain this", "Explain this"])
        #expect(client.sentInputs.map(\.customInstructions) == [
            "Use the first preference",
            "Use the latest preference"
        ])
        #expect(client.sentInputs.map(\.personality) == [.pragmatic, .friendly])
        #expect(viewModel.items.last { $0.kind == .user }?.content == "Explain this")
    }

    @Test @MainActor func onboardingResumePreservesCapturedInstructions() async {
        var savedInstructions = "Keep the captured preference"
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = OnboardFirstMessageClient()
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent.config,
            client: client,
            customInstructionsProvider: { savedInstructions }
        )

        viewModel.send("What can you do?")
        await waitUntil { viewModel.pendingOnboard != nil }
        savedInstructions = "A newer preference"
        viewModel.submitOnboard(inviteCode: "OpenOnion")
        await waitUntil { client.sentInputs.count == 2 && viewModel.pendingOnboard == nil }

        #expect(client.sentInputs.map(\.customInstructions) == [
            "Keep the captured preference",
            "Keep the captured preference"
        ])
        #expect(conversation.messages.contains { $0.kind == .user && $0.content == "What can you do?" })
    }

    @Test @MainActor func canonicalHistoryIsSanitizedBeforeDisplayAndPersistence() async {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = CanonicalCustomInstructionsClient()
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent.config,
            client: client,
            customInstructionsProvider: { "Answer as a tutor" }
        )

        viewModel.send("Explain recursion")
        await waitUntil { viewModel.sessionState == .connected && viewModel.items.last?.kind == .agent }

        #expect(viewModel.items.first { $0.kind == .user }?.content == "Explain recursion")
        #expect(conversation.messages.first { $0.kind == .user }?.content == "Explain recursion")
        #expect(!conversation.messages.contains { $0.content.contains("CONNECTONION_CUSTOM_INSTRUCTIONS") })
    }

    @Test @MainActor func hostSystemRemindersAreRemovedFromCanonicalHistory() async {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = CanonicalSystemReminderClient()
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent.config,
            client: client,
            customInstructionsProvider: { "Answer as a tutor" }
        )

        viewModel.send("Explain recursion")
        await waitUntil { viewModel.sessionState == .connected && viewModel.items.last?.kind == .agent }

        let visibleUserMessages = viewModel.items.filter { $0.kind == .user }.map(\.content)
        let persistedUserMessages = conversation.messages.filter { $0.kind == .user }.map(\.content)
        #expect(visibleUserMessages == ["Explain recursion"])
        #expect(persistedUserMessages == ["Explain recursion"])
        #expect(!viewModel.items.contains { $0.content.contains("<system-reminder>") })
        #expect(!conversation.messages.contains { $0.content.contains("<system-reminder>") })
    }

    @Test @MainActor func persistedReminderOnlyMessagesAreRepairedWhenConversationLoads() {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        conversation.messages = [
            ChatItem(id: "user", kind: .user, content: "Write it in Java"),
            ChatItem(id: "agent", kind: .agent, content: "Here is the Java version"),
            ChatItem(
                id: "leaked-reminder",
                kind: .user,
                content: "<system-reminder>\nHidden agent instructions\n</system-reminder>"
            )
        ]
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")

        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config)

        #expect(viewModel.items.map(\.id) == ["user", "agent"])
        #expect(conversation.messages.map(\.id) == ["user", "agent"])
    }
}

@MainActor
private final class CanonicalCustomInstructionsClient: ConnectOnionClientProviding {
    func send(
        input: AgentInput,
        to agent: AgentConfig,
        session: ConversationSession
    ) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        var userItem = ChatItem(id: "canonical-user", kind: .user, content: input.transmittedPrompt)
        userItem.images = input.images
        userItem.files = input.files
        let agentItem = ChatItem(id: "canonical-agent", kind: .agent, content: "Recursion calls itself")

        return AsyncThrowingStream { continuation in
            continuation.yield(.connected(
                sessionID: session.id.uuidString,
                status: "connected",
                serverNewer: false,
                session: nil,
                chatItems: []
            ))
            continuation.yield(.output(
                result: "Recursion calls itself",
                session: nil,
                chatItems: [userItem, agentItem]
            ))
            continuation.finish()
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
    func disconnect() {}
}

@MainActor
private final class CanonicalSystemReminderClient: ConnectOnionClientProviding {
    func send(
        input: AgentInput,
        to agent: AgentConfig,
        session: ConversationSession
    ) -> AsyncThrowingStream<ConnectOnionClientEvent, Error> {
        let reminder = """
        <system-reminder>
        Hidden agent-building instructions
        </system-reminder>
        """
        let userItem = ChatItem(
            id: "canonical-user",
            kind: .user,
            content: "\(reminder)\n\n\(input.transmittedPrompt)"
        )
        let leakedReminder = ChatItem(
            id: "canonical-reminder",
            kind: .user,
            content: reminder
        )
        let agentItem = ChatItem(id: "canonical-agent", kind: .agent, content: "Recursion calls itself")

        return AsyncThrowingStream { continuation in
            continuation.yield(.connected(
                sessionID: session.id.uuidString,
                status: "connected",
                serverNewer: false,
                session: nil,
                chatItems: []
            ))
            continuation.yield(.output(
                result: "Recursion calls itself",
                session: nil,
                chatItems: [userItem, leakedReminder, agentItem]
            ))
            continuation.finish()
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
    func disconnect() {}
}
