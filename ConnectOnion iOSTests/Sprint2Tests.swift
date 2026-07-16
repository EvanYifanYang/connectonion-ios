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
        await waitUntil { client.reconnectCount == 1 && viewModel.sessionState == .connected }

        #expect(client.reconnectCount == 1)
        #expect(viewModel.sessionState == .connected)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.items.contains { $0.kind == .agent && $0.content == "Recovered image reply" })
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
