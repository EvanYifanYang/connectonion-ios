//
//  Sprint2Tests.swift
//
//  Purpose: Implements Sprint2Tests for the ConnectOnion iOSTests module.
//  Collaborates with: AgentQRCodePayloadTests, AgentRoutingTests, ChatSessionStoreTests, CustomInstructionsTests, PersonalisationPreferencesTests, Sprint1Tests.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import ConnectOnion_iOS

// MARK: - Sprint 2 — new surfaces
//
// Sprint 2 built on the Sprint-1 chat path: native attachments + multimodal input,
// agent display-name precedence, onboarding-gated first prompt resend, and the
// system surfaces (Widget + Live Activity via the shared App-Group module and deep
// links). These suites cover that new behaviour hermetically.

@Suite("Sprint 2 — Agent display name precedence")
struct Sprint2DisplayNameTests {
    @Test func localAliasOverridesRemoteAgentInfoName() {
        let agent = AgentConfigRecord(address: testAgentAddress, alias: " A1 ")
        let info = AgentInfo(address: testAgentAddress, name: "Previous Name", online: true)

        #expect(agent.displayName(info: info) == "A1")
    }

    @Test func remoteAgentInfoNameIsFallbackWhenAliasIsEmpty() {
        let agent = AgentConfigRecord(address: testAgentAddress, alias: " ")
        let info = AgentInfo(address: testAgentAddress, name: "Remote Name", online: true)

        #expect(agent.displayName(info: info) == "Remote Name")
    }

    @Test func remoteProfileNameAppearsOnlyWhenDifferentFromLocalAlias() {
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "A1")
        let matchingInfo = AgentInfo(address: testAgentAddress, name: "a1", online: true)
        let differentInfo = AgentInfo(address: testAgentAddress, name: "OpenOnion", online: true)

        #expect(agent.remoteProfileName(info: matchingInfo) == nil)
        #expect(agent.remoteProfileName(info: differentInfo) == "OpenOnion")
    }
}

@Suite("Sprint 2 — Attachment encoding")
struct Sprint2AttachmentEncodingTests {
    @Test func createsAndDecodesDataURLAttachments() throws {
        // Note: `UTType.markdown` is iOS-27-only; `.plainText` (iOS 14+) exercises the same
        // encode → data-URL → decode round-trip on the iOS 26 SDK.
        let data = try #require("readme".data(using: .utf8))
        let attachment = AttachmentEncoding.fileAttachment(
            name: "notes.txt",
            contentType: .plainText,
            data: data
        )

        #expect(attachment.name == "notes.txt")
        #expect(attachment.type == "text/plain")
        #expect(attachment.size == data.count)
        #expect(attachment.dataURL.hasPrefix("data:text/plain;base64,"))
        #expect(AttachmentEncoding.decodedData(from: attachment.dataURL) == data)
    }

    @Test func imagePayloadRespectsEncodedBudget() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1800, height: 1800))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1800, height: 1800))
        }
        let data = try #require(image.pngData())
        let budget = 220 * 1024

        let payload = try #require(AttachmentEncoding.imagePayload(data: data, maxEncodedBytes: budget))

        #expect(payload.encodedSize <= budget)
        #expect(payload.dataURL.hasPrefix("data:image/jpeg;base64,"))
    }
}

@Suite("Sprint 2 — Multimodal composer (send + persist attachments)")
struct Sprint2AttachmentComposerTests {
    @Test @MainActor func inputMessageCarriesAttachmentsAndSignedPayload() throws {
        let codec = ProtocolCodec(identityStore: MockIdentityStore())

        let input = AgentInput(
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
        )
        let message = try codec.inputMessage(
            input: input,
            agentAddress: testAgentAddress,
            route: .relay(webSocketURL: URL(string: "wss://relay.example/ws/input")!)
        )

        #expect(message[string: "type"] == "INPUT")
        #expect(message[string: "prompt"] == input.transmittedPrompt)
        #expect(message[string: "to"] == testAgentAddress)
        #expect(message[string: "from"]?.hasPrefix("0x") == true)
        #expect(message[string: "signature"]?.count == 128)
        #expect(message["images"]?.arrayValue?.count == 1)
        #expect(message["files"]?.arrayValue?.count == 1)

        let payload = message["payload"]?.objectValue
        #expect(payload?[string: "prompt"] == input.transmittedPrompt)
        #expect(payload?[string: "to"] == testAgentAddress)
        #expect(payload?[int: "timestamp"] == message[int: "timestamp"])
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
        await waitUntil { viewModel.items.contains { $0.kind == .agent } }

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

    @Test @MainActor func attachmentFailureAutomaticallyReconnectsAndRecoversReply() async throws {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = AttachmentRecoveryClient()
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        viewModel.send("What is in this image?", images: ["data:image/png;base64,aW1hZ2U="])
        // Gate on the recovered reply actually landing, not just on reconnect + connected: the
        // recovery bubble is appended at the reconnect's terminal .output, which can arrive a beat
        // after sessionState flips to .connected — reading items before then is a cold-run flake.
        await waitUntil {
            client.reconnectCount == 1 && viewModel.sessionState == .connected
                && viewModel.items.contains { $0.kind == .agent && $0.content == "Recovered image reply" }
        }

        #expect(client.reconnectCount == 1)
        #expect(viewModel.sessionState == .connected)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.items.contains { $0.kind == .agent && $0.content == "Recovered image reply" })
    }
}

@Suite("Sprint 2 — Reply regeneration state")
struct Sprint2ReplyRegenerationTests {
    @Test @MainActor func regenerateForksFromRetainedHistoryAndReplacesLatestTurn() async throws {
        let previousUser = ChatItem(id: "previous-user", kind: .user, content: "Previous prompt")
        let previousReply = ChatItem(id: "previous-reply", kind: .agent, content: "Previous reply")
        let latestUser = ChatItem(id: "latest-user", kind: .user, content: "Latest prompt")
        let latestReply = ChatItem(id: "latest-reply", kind: .agent, content: "Latest reply")
        let conversation = ConversationRecord(
            agentAddress: testAgentAddress,
            remoteSessionID: "remote-original",
            messages: [previousUser, previousReply, latestUser, latestReply],
            rawSession: .object(["state": .string("old")]),
            lastRenderedEventID: "event-old"
        )
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = StreamingConnectOnionClient(replyText: "Replacement reply")
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        viewModel.regenerate()
        await waitUntil { client.sentSessions.count == 1 && viewModel.sessionState == .connected }

        let replacementSession = try #require(client.sentSessions.first)
        #expect(replacementSession.remoteSessionID != "remote-original")
        #expect(replacementSession.messages == [previousUser, previousReply])
        #expect(replacementSession.rawSession == nil)
        #expect(replacementSession.lastRenderedEventID == nil)
        #expect(client.sentInputs.first?.prompt == "Latest prompt")
        #expect(conversation.remoteSessionID == replacementSession.remoteSessionID)
        #expect(viewModel.items.map(\.content) == [
            "Previous prompt", "Previous reply", "Latest prompt", "Replacement reply"
        ])
    }

    @Test @MainActor func failedRegenerateAfterPartialEventsRestoresOriginalExchange() async {
        let originalUser = ChatItem(id: "original-user", kind: .user, content: "Original prompt")
        var originalReply = ChatItem(id: "original-reply", kind: .agent, content: "Original reply")
        originalReply.model = "co/original"
        let originalItems = [originalUser, originalReply]
        let originalRawSession = JSONValue.object(["state": .string("old")])
        let conversation = ConversationRecord(
            agentAddress: testAgentAddress,
            remoteSessionID: "remote-original",
            messages: originalItems,
            rawSession: originalRawSession,
            lastRenderedEventID: "event-old"
        )
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent.config,
            client: PartialRegenerateFailureClient()
        )

        viewModel.regenerate()
        await waitUntil { viewModel.errorMessage != nil }

        #expect(viewModel.items == originalItems)
        #expect(conversation.messages == originalItems)
        #expect(viewModel.sessionState == .connected)
        #expect(viewModel.lastResponseModel == "co/original")
        #expect(conversation.remoteSessionID == "remote-original")
        #expect(conversation.rawSession == originalRawSession)
        #expect(conversation.lastRenderedEventID == "event-old")
    }

    @Test @MainActor func emptyRegenerateOutputRestoresOriginalExchange() async {
        let originalUser = ChatItem(id: "original-user", kind: .user, content: "Original prompt")
        let originalReply = ChatItem(id: "original-reply", kind: .agent, content: "Original reply")
        let originalItems = [originalUser, originalReply]
        let conversation = ConversationRecord(
            agentAddress: testAgentAddress,
            remoteSessionID: "remote-original",
            messages: originalItems,
            rawSession: .object(["state": .string("old")]),
            lastRenderedEventID: "event-old"
        )
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent.config,
            client: EmptyRegenerateOutputClient()
        )

        viewModel.regenerate()
        await waitUntil { viewModel.errorMessage != nil }

        #expect(viewModel.items == originalItems)
        #expect(conversation.messages == originalItems)
        #expect(conversation.remoteSessionID == "remote-original")
        #expect(conversation.lastRenderedEventID == "event-old")
        #expect(viewModel.sessionState == .connected)
    }

    @Test @MainActor func outputWithoutModelDoesNotReusePreviousTurnsModel() async {
        let previousUser = ChatItem(id: "previous-user", kind: .user, content: "Previous prompt")
        var previousReply = ChatItem(id: "previous-reply", kind: .agent, content: "Previous reply")
        previousReply.model = "co/previous"
        let conversation = ConversationRecord(
            agentAddress: testAgentAddress,
            messages: [previousUser, previousReply]
        )
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = StreamingConnectOnionClient(replyText: "Current reply")
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        viewModel.send("Current prompt")
        await waitUntil { viewModel.items.contains { $0.kind == .agent && $0.content == "Current reply" } }

        let currentReply = viewModel.items.last { $0.kind == .agent }
        #expect(currentReply?.content == "Current reply")
        #expect(currentReply?.model == nil)
        #expect(viewModel.lastResponseModel == nil)
    }
}

@Suite("Sprint 2 — Latest message editing")
struct Sprint2LatestMessageEditingTests {
    @Test @MainActor func editedLatestTurnReplacesExchangeAndPreservesAttachments() async throws {
        let previousUser = ChatItem(id: "previous-user", kind: .user, content: "Previous prompt")
        let previousReply = ChatItem(id: "previous-reply", kind: .agent, content: "Previous reply")
        var latestUser = ChatItem(id: "latest-user", kind: .user, content: "Original prompt")
        latestUser.images = ["data:image/png;base64,aW1hZ2U="]
        latestUser.files = [FileAttachment(
            id: "readme",
            name: "README.md",
            type: "text/markdown",
            size: 6,
            dataURL: "data:text/markdown;base64,cmVhZG1l"
        )]
        var latestReply = ChatItem(id: "latest-reply", kind: .agent, content: "Original reply")
        latestReply.model = "co/original"
        let conversation = ConversationRecord(
            agentAddress: testAgentAddress,
            remoteSessionID: "remote-original",
            title: "Existing title",
            messages: [previousUser, previousReply, latestUser, latestReply],
            rawSession: .object(["state": .string("old")]),
            lastRenderedEventID: "event-old"
        )
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = StreamingConnectOnionClient(replyText: "Edited reply")
        let viewModel = ChatViewModel(
            conversation: conversation,
            agent: agent.config,
            client: client,
            customInstructionsProvider: { "Use the latest preference" },
            personalityProvider: { .friendly }
        )

        #expect(viewModel.editableLatestUserMessageID == latestUser.id)
        #expect(!viewModel.editLatestUserMessage(id: previousUser.id, prompt: "Stale edit"))
        #expect(viewModel.editLatestUserMessage(id: latestUser.id, prompt: "  Edited prompt  "))
        await waitUntil { client.sentInputs.count == 1 && viewModel.sessionState == .connected }

        let sent = try #require(client.sentInputs.first)
        let replacementSession = try #require(client.sentSessions.first)
        #expect(sent.prompt == "Edited prompt")
        #expect(sent.images == latestUser.images)
        #expect(sent.files == latestUser.files)
        #expect(sent.customInstructions == "Use the latest preference")
        #expect(sent.personality == .friendly)
        #expect(replacementSession.remoteSessionID != "remote-original")
        #expect(replacementSession.messages == [previousUser, previousReply])
        #expect(replacementSession.rawSession == nil)
        #expect(replacementSession.lastRenderedEventID == nil)
        #expect(conversation.remoteSessionID == replacementSession.remoteSessionID)
        #expect(viewModel.items.map(\.content) == [
            "Previous prompt", "Previous reply", "Edited prompt", "Edited reply"
        ])
        #expect(conversation.messages == viewModel.items)
        #expect(conversation.title == "Existing title")
        if let streamingMessageID = viewModel.streamingMessageID {
            viewModel.markStreamingComplete(streamingMessageID)
        }
        #expect(viewModel.editableLatestUserMessageID == viewModel.items.last { $0.kind == .user }?.id)
    }

    @Test @MainActor func failedOrStoppedEditRestoresOriginalExchange() async {
        let user = ChatItem(id: "latest-user", kind: .user, content: "Original prompt")
        var reply = ChatItem(id: "latest-reply", kind: .agent, content: "Original reply")
        reply.model = "co/original"
        let originalItems = [user, reply]
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")

        let originalRawSession = JSONValue.object(["state": .string("old")])
        let failedConversation = ConversationRecord(
            agentAddress: testAgentAddress,
            remoteSessionID: "remote-original",
            messages: originalItems,
            rawSession: originalRawSession,
            lastRenderedEventID: "event-old"
        )
        let failedViewModel = ChatViewModel(
            conversation: failedConversation,
            agent: agent.config,
            client: PartialRegenerateFailureClient()
        )
        #expect(failedViewModel.editLatestUserMessage(id: user.id, prompt: "Failed edit"))
        await waitUntil { failedViewModel.errorMessage != nil }
        #expect(failedViewModel.items == originalItems)
        #expect(failedConversation.messages == originalItems)
        #expect(failedConversation.remoteSessionID == "remote-original")
        #expect(failedConversation.rawSession == originalRawSession)
        #expect(failedConversation.lastRenderedEventID == "event-old")
        #expect(failedViewModel.editableLatestUserMessageID == nil)

        let stoppedConversation = ConversationRecord(
            agentAddress: testAgentAddress,
            remoteSessionID: "remote-original",
            messages: originalItems,
            rawSession: originalRawSession,
            lastRenderedEventID: "event-old"
        )
        let controlledClient = ControlledReplyClient()
        let stoppedViewModel = ChatViewModel(
            conversation: stoppedConversation,
            agent: agent.config,
            client: controlledClient
        )
        #expect(stoppedViewModel.editLatestUserMessage(id: user.id, prompt: "Stopped edit"))
        await waitUntil { stoppedViewModel.sessionState == .active }
        stoppedViewModel.stop()
        #expect(stoppedViewModel.items == originalItems)
        #expect(stoppedConversation.messages == originalItems)
        #expect(stoppedConversation.remoteSessionID == "remote-original")
        #expect(stoppedConversation.rawSession == originalRawSession)
        #expect(stoppedConversation.lastRenderedEventID == "event-old")
        #expect(stoppedViewModel.editableLatestUserMessageID == nil)
    }

    @Test @MainActor func eligibilityRequiresCompletedUnblockedLatestTurn() {
        let user = ChatItem(id: "latest-user", kind: .user, content: "Prompt")
        let reply = ChatItem(id: "latest-reply", kind: .agent, content: "Reply")
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")

        let completed = ChatViewModel(
            conversation: ConversationRecord(agentAddress: testAgentAddress, messages: [user, reply]),
            agent: agent.config,
            client: StreamingConnectOnionClient()
        )
        #expect(completed.editableLatestUserMessageID == user.id)
        completed.streamingMessageID = reply.id
        #expect(completed.editableLatestUserMessageID == nil)
        completed.markStreamingComplete(reply.id)
        #expect(completed.editableLatestUserMessageID == user.id)
        #expect(!completed.editLatestUserMessage(id: user.id, prompt: "Prompt"))
        #expect(!completed.editLatestUserMessage(id: user.id, prompt: "   "))

        let unanswered = PreviewFixtures.sampleAskUser
        let blocked = ChatViewModel(
            conversation: ConversationRecord(
                agentAddress: testAgentAddress,
                messages: [user, reply, unanswered]
            ),
            agent: agent.config,
            client: StreamingConnectOnionClient()
        )
        #expect(blocked.editableLatestUserMessageID == nil)

        let incomplete = ChatViewModel(
            conversation: ConversationRecord(agentAddress: testAgentAddress, messages: [user]),
            agent: agent.config,
            client: StreamingConnectOnionClient()
        )
        #expect(incomplete.editableLatestUserMessageID == nil)
    }

    @Test @MainActor func attachmentTurnMayBeEditedToEmptyText() async {
        var user = ChatItem(id: "attached-user", kind: .user, content: "Describe this")
        user.images = ["data:image/png;base64,aW1hZ2U="]
        let reply = ChatItem(id: "attached-reply", kind: .agent, content: "Description")
        let conversation = ConversationRecord(agentAddress: testAgentAddress, messages: [user, reply])
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = StreamingConnectOnionClient(replyText: "Updated description")
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        #expect(viewModel.editLatestUserMessage(id: user.id, prompt: "   "))
        await waitUntil { client.sentInputs.count == 1 && viewModel.sessionState == .connected }
        #expect(client.sentInputs.first?.prompt == "")
        #expect(client.sentInputs.first?.images == user.images)
    }
}

@Suite("Sprint 2 — Onboarding-gated first prompt resend")
struct Sprint2OnboardingTests {
    @Test @MainActor func firstPromptThatTriggersOnboardingResendsOriginalInputAfterInviteSuccess() async throws {
        let conversation = ConversationRecord(agentAddress: testAgentAddress)
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        let client = OnboardFirstMessageClient()
        let viewModel = ChatViewModel(conversation: conversation, agent: agent.config, client: client)

        viewModel.send("What can you do?")
        await waitUntil { viewModel.pendingOnboard != nil }

        #expect(client.sentInputs.map(\.prompt) == ["What can you do?"])
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items[0].kind == .onboardRequired)
        #expect(!viewModel.items.contains { $0.kind == .user })
        #expect(!conversation.messages.contains { $0.kind == .user })
        #expect(viewModel.pendingOnboard != nil)

        viewModel.submitOnboard(inviteCode: "OpenOnion")
        await waitUntil {
            viewModel.pendingOnboard == nil
                && conversation.messages.contains { $0.kind == .user && $0.content == "What can you do?" }
        }

        #expect(viewModel.pendingOnboard == nil)
        #expect(client.sentInputs.map(\.prompt) == ["What can you do?", "What can you do?"])
        #expect(conversation.messages.contains { $0.kind == .user && $0.content == "What can you do?" })
        #expect(conversation.title == "What can you do?")
    }
}

@Suite("Sprint 2 — Widget & Live Activity deep links")
struct Sprint2DeepLinkTests {
    @Test func newChatDeepLinkRoundTripsAgentAndSuggestion() throws {
        let url = ConnectOnionDeepLink.newChat(agentAddress: "0xabc", suggestion: "Plan the next step")
        let request = try #require(ConnectOnionDeepLink.parse(url))

        #expect(request.agentAddress == "0xabc")
        #expect(request.suggestion == "Plan the next step")
        #expect(request.conversationID == nil)
    }

    @Test func conversationDeepLinkRoundTripsConversationID() throws {
        let url = ConnectOnionDeepLink.conversation(id: "C9F4D04E-6D26-4F70-9808-74F09752D6D1")
        let request = try #require(ConnectOnionDeepLink.parse(url))

        #expect(request.conversationID == "C9F4D04E-6D26-4F70-9808-74F09752D6D1")
        #expect(request.agentAddress == nil)
        #expect(request.suggestion == nil)
    }

    @Test func scanAgentDeepLinkOpensScanner() throws {
        let request = try #require(ConnectOnionDeepLink.parse(ConnectOnionDeepLink.scanAgent()))

        #expect(request.opensAgentScanner)
        #expect(request.agentAddress == nil)
        #expect(request.suggestion == nil)
        #expect(request.conversationID == nil)
    }

    @Test func rejectsForeignSchemeURL() {
        #expect(ConnectOnionDeepLink.parse(URL(string: "https://example.com/new-chat?agent=0xabc")!) == nil)
    }
}

@Suite("Sprint 2 — Widget snapshot persistence")
struct Sprint2WidgetSnapshotTests {
    @Test func snapshotEncodesAndDecodesForCrossProcessSharing() throws {
        let snapshot = ConnectOnionWidgetSnapshot(
            updatedAt: Date(timeIntervalSince1970: 100),
            agents: [
                ConnectOnionAgentShortcut(
                    address: "0xabc",
                    displayName: "OpenOnion",
                    subtitle: "Last used just now",
                    lastUsedAt: Date(timeIntervalSince1970: 50),
                    suggestions: ConnectOnionSharedSuggestions.defaults
                )
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ConnectOnionWidgetSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.agents.first?.id == "0xabc")
        #expect(decoded.agents.first?.suggestions == ConnectOnionSharedSuggestions.defaults)
    }
}
