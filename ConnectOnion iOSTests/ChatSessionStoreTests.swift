import Testing
@testable import ConnectOnion_iOS

@Suite("Chat sessions — background replies")
struct ChatSessionStoreTests {
    @Test @MainActor func offscreenReplyCompletesAndMarksConversationUnread() async {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = ControlledReplyClient()
        let store = ChatSessionStore()
        let viewModel = store.viewModel(for: conversation, agent: agent.config, client: client)

        store.setVisibleConversation(id: nil, conversation: nil)
        viewModel.send("Finish this in the background")
        await waitUntil { viewModel.sessionState == .active }
        #expect(store.isGeneratingReply(for: conversation.id))

        client.complete(with: "Background reply")
        await waitUntil { viewModel.sessionState == .connected }

        #expect(conversation.hasUnread)
        #expect(viewModel.streamingMessageID == nil)
        #expect(conversation.messages.contains { $0.kind == .agent && $0.content == "Background reply" })
        #expect(store.viewModel(for: conversation, agent: agent.config) === viewModel)
    }

    @Test @MainActor func visibleReplyCompletesWithoutUnreadAndOpeningClearsExistingUnread() async {
        let conversation = ConversationRecord(agentAddress: testAgentAddress, hasUnread: true)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = ControlledReplyClient()
        let store = ChatSessionStore()
        let viewModel = store.viewModel(for: conversation, agent: agent.config, client: client)

        store.setVisibleConversation(id: conversation.id, conversation: conversation)
        #expect(!conversation.hasUnread)

        viewModel.send("Keep this chat open")
        await waitUntil { viewModel.sessionState == .active }
        #expect(store.isGeneratingReply(for: conversation.id))
        client.complete(with: "Foreground reply")
        await waitUntil { viewModel.sessionState == .connected }

        #expect(!conversation.hasUnread)
        #expect(viewModel.streamingMessageID != nil)
    }

    @Test @MainActor func removingAnActiveSessionStopsItsOwnedClient() async {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = ControlledReplyClient()
        let store = ChatSessionStore()
        let viewModel = store.viewModel(for: conversation, agent: agent.config, client: client)

        viewModel.send("Keep working")
        await waitUntil { viewModel.sessionState == .active }
        #expect(store.isGeneratingReply(for: conversation.id))
        store.removeSession(for: conversation.id)

        #expect(client.disconnectCount == 1)
        #expect(!store.isGeneratingReply(for: conversation.id))
        #expect(viewModel.sessionState == .connected)
    }
}
