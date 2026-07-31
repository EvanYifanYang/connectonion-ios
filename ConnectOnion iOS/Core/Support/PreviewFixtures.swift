//
//  PreviewFixtures.swift
//
//  Purpose: Implements PreviewFixtures for the Core/Support module.
//  Collaborates with: AccessibilityID, AgentContentSanitizer, AttachmentEncoding, CustomInstructions, HexCoding, JSONValue.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation
import Factory
import SwiftData

@MainActor
enum PreviewFixtures {
    enum Scenario: String {
        case standard
        case empty
        case metadataEmpty = "metadata-empty"
        case approval
        case askText = "ask-text"
        case askOptions = "ask-options"
        case askFields = "ask-fields"
        case onboard
        case onboardFirstMessage = "onboard-first-message"
        case planReview = "plan-review"
    }

    static let testAgentAddress = "0xf5ff043a9c5df95eac9387908dea87beb7b59c2a3b04787e3222fdf8209cdee1"
    static let sampleConversationID = UUID(uuidString: "C9F4D04E-6D26-4F70-9808-74F09752D6D1") ?? UUID()

    static func scenario(from arguments: [String]) -> Scenario {
        arguments
            .compactMap { argument -> Scenario? in
                guard argument.hasPrefix("--ui-testing-scenario=") else { return nil }
                return Scenario(rawValue: String(argument.dropFirst("--ui-testing-scenario=".count)))
            }
            .first ?? .standard
    }

    static func container() -> ModelContainer {
        let schema = Schema([AgentConfigRecord.self, ConversationRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create preview ModelContainer: \(error)")
        }
    }

    static func installMockDependencies(scenario: Scenario = .standard) {
        Container.shared.identityStore.register { @MainActor in MockIdentityStore() }
        Container.shared.connectOnionClient.register { @MainActor in
            MockConnectOnionClient(mode: scenario == .onboardFirstMessage ? .onboardFirstMessage : .standard)
        }
        Container.shared.agentDirectoryService.register {
            MockAgentDirectoryService(includesCapabilities: scenario != .metadataEmpty)
        }
    }

    static var sampleAgent: AgentConfigRecord {
        let agent = AgentConfigRecord(address: testAgentAddress, alias: "OpenOnion")
        agent.cachedInfo = sampleAgentInfo
        return agent
    }

    static var sampleConversation: ConversationRecord {
        let conversation = ConversationRecord(id: sampleConversationID, agentAddress: testAgentAddress, title: "What can you do?")
        conversation.messages = sampleMessages
        return conversation
    }

    static func sampleConversation(for scenario: Scenario) -> ConversationRecord {
        switch scenario {
        case .standard, .empty, .metadataEmpty, .onboardFirstMessage:
            return sampleConversation
        case .approval:
            return conversation(title: "Approval flow", messages: [sampleUserMessage, sampleApproval])
        case .askText:
            return conversation(title: "Ask text flow", messages: [sampleUserMessage, sampleAskUserText])
        case .askOptions:
            return conversation(title: "Ask options flow", messages: [sampleUserMessage, sampleAskUser])
        case .askFields:
            return conversation(title: "Ask fields flow", messages: [sampleUserMessage, sampleAskUserFields])
        case .onboard:
            return conversation(title: "Invite flow", messages: [sampleOnboardRequired])
        case .planReview:
            return conversation(title: "Plan review flow", messages: [sampleUserMessage, samplePlanReview])
        }
    }

    static var sampleAgentInfo: AgentInfo {
        AgentInfo(
            address: testAgentAddress,
            name: "OpenOnion",
            tools: ["bash", "read_file", "ask_user", "write_file", "search", "plan_review", "eval"],
            skills: sampleSkills,
            trust: "careful",
            version: "1.0",
            model: "co/gemini-2.5-flash",
            acceptedInputs: AgentAcceptedInputs(text: true, images: true, files: .init(maxFileSizeMB: 10, maxFilesPerRequest: 4)),
            online: true
        )
    }

    static var sampleAgentInfoWithoutCapabilities: AgentInfo {
        var info = sampleAgentInfo
        info.tools = []
        info.skills = []
        return info
    }

    static var sampleSkills: [SkillInfo] {
        [
            SkillInfo(name: "summarize", description: "Summarize a document"),
            SkillInfo(name: "research", description: "Research a topic"),
            SkillInfo(name: "debug", description: "Debug an error"),
            SkillInfo(name: "ship", description: "Prepare a release"),
            SkillInfo(name: "audit", description: "Review a codebase"),
            SkillInfo(name: "explain", description: "Explain a tricky file"),
            SkillInfo(name: "translate", description: "Translate selected content"),
            SkillInfo(name: "organize", description: "Organize notes into a plan")
        ]
    }

    static var sampleFiles: [FileAttachment] {
        [
            FileAttachment(name: "README.md", type: "text/markdown", size: 6400, dataURL: "data:text/markdown;base64,cmVhZG1l"),
            FileAttachment(name: "diagram.png", type: "image/png", size: 12_300, dataURL: "data:image/png;base64,aW1hZ2U=")
        ]
    }

    static var sampleUserMessage: ChatItem {
        var item = ChatItem(id: "preview-user", kind: .user, content: "Can you inspect this project and suggest the next step?")
        item.files = sampleFiles
        return item
    }

    static var sampleAgentMessage: ChatItem {
        ChatItem(id: "preview-agent", kind: .agent, content: "I found the main app shell, networking layer, and chat reducer. The next step is to verify the signed INPUT frame against the agent.")
    }

    static var sampleThinking: ChatItem {
        var item = ChatItem(id: "preview-thinking", kind: .thinking)
        item.status = .running
        item.model = "co/gemini-2.5-flash"
        return item
    }

    static var sampleThinkingDone: ChatItem {
        var item = sampleThinking
        item.status = .done
        item.usage = TokenUsage(totalTokens: 1280, cost: 0.003)
        return item
    }

    static var sampleToolCall: ChatItem {
        var item = ChatItem(id: "preview-tool", kind: .toolCall)
        item.name = "read_file"
        item.arguments = ["path": .string("ConnectOnion_iOSApp.swift")]
        item.status = .done
        item.result = "Loaded the SwiftUI app entry point and verified the SwiftData model container setup."
        item.timingMS = 420
        return item
    }

    static var sampleToolCallRunning: ChatItem {
        var item = sampleToolCall
        item.status = .running
        item.result = nil
        return item
    }

    static var sampleAskUser: ChatItem {
        var item = ChatItem(id: "preview-ask-user", kind: .askUser)
        item.content = "Which verification mode should I use?"
        item.options = ["Quick smoke test", "Full simulator test", "Protocol-only check"]
        item.multiSelect = true
        return item
    }

    static var sampleAskUserText: ChatItem {
        var item = ChatItem(id: "preview-ask-user-text", kind: .askUser)
        item.content = "What should I focus on?"
        return item
    }

    static var sampleAskUserFields: ChatItem {
        var item = ChatItem(id: "preview-ask-user-fields", kind: .askUser)
        item.content = "Agent credentials"
        item.fields = [
            AskUserField(name: "username", label: "Username", type: .text, placeholder: nil, required: true, autocomplete: nil),
            AskUserField(name: "token", label: "Token", type: .password, placeholder: nil, required: true, autocomplete: nil)
        ]
        return item
    }

    static var sampleApproval: ChatItem {
        var item = ChatItem(id: "preview-approval", kind: .approvalNeeded)
        item.tool = "bash"
        item.description = "Run the test suite on the iPhone 17 simulator."
        item.arguments = ["command": .string("xcodebuild test")]
        return item
    }

    static var sampleOnboardRequired: ChatItem {
        var item = ChatItem(id: "preview-onboard", kind: .onboardRequired)
        item.methods = ["invite_code", "payment"]
        item.paymentAmount = 3.50
        return item
    }

    static var sampleOnboardSuccess: ChatItem {
        ChatItem(id: "preview-onboard-success", kind: .onboardSuccess, content: "Invite accepted")
    }

    static var sampleToolBlocked: ChatItem {
        ChatItem(id: "preview-tool-blocked", kind: .toolBlocked, content: "Tool blocked by current approval mode")
    }

    static var samplePlanReview: ChatItem {
        var item = ChatItem(id: "preview-plan", kind: .planReview)
        item.planContent = """
        1. Resolve the agent route.
        2. Send signed CONNECT and INPUT frames.
        3. Stream tool and assistant events into SwiftUI.
        """
        return item
    }

    static var sampleFilesReceived: ChatItem {
        var item = ChatItem(id: "preview-files", kind: .filesReceived)
        item.receivedFiles = [
            ReceivedFile(name: "summary.md", path: "/tmp/summary.md"),
            ReceivedFile(name: "trace.json", path: "/tmp/trace.json")
        ]
        return item
    }

    static var sampleEvaluation: ChatItem {
        var item = ChatItem(id: "preview-eval", kind: .evaluation)
        item.status = .done
        item.passed = true
        item.content = "All smoke checks passed"
        return item
    }

    static var sampleEvaluationFailed: ChatItem {
        var item = sampleEvaluation
        item.passed = false
        item.content = "Smoke check failed"
        return item
    }

    static var sampleCompact: ChatItem {
        var item = ChatItem(id: "preview-compact", kind: .compact)
        item.status = .done
        item.content = "Context compacted to 42%"
        return item
    }

    static var sampleIntent: ChatItem {
        var item = ChatItem(id: "preview-intent", kind: .intent)
        item.status = .understood
        item.ack = "Build an iOS client"
        return item
    }

    static var sampleIntentAnalyzing: ChatItem {
        var item = sampleIntent
        item.status = .analyzing
        item.ack = nil
        return item
    }

    static func seededContainer(scenario: Scenario = .standard) -> ModelContainer {
        let container = container()
        guard scenario != .empty else { return container }

        let context = container.mainContext
        let agent = sampleAgent
        if scenario == .metadataEmpty {
            agent.cachedInfo = sampleAgentInfoWithoutCapabilities
        }
        context.insert(agent)

        guard scenario != .onboardFirstMessage else { return container }

        let conversation = sampleConversation(for: scenario)
        context.insert(conversation)
        return container
    }

    static var sampleMessages: [ChatItem] {
        var thinking = ChatItem(id: "thinking-1", kind: .thinking)
        thinking.status = .done
        thinking.model = "co/gemini-2.5-flash"
        thinking.usage = TokenUsage(totalTokens: 1280, cost: 0.003)

        var tool = ChatItem(id: "tool-1", kind: .toolCall)
        tool.name = "read_file"
        tool.arguments = ["path": .string("README.md")]
        tool.status = .done
        tool.result = "ConnectOnion helps agents expose tools over a signed WebSocket protocol."
        tool.timingMS = 480

        return [
            ChatItem(id: "user-1", kind: .user, content: "What can you do?"),
            thinking,
            tool,
            ChatItem(id: "agent-1", kind: .agent, content: "I can connect to a remote ConnectOnion agent, stream progress, ask for approval, and keep this session alive across reconnects.")
        ]
    }

    private static func conversation(title: String, messages: [ChatItem]) -> ConversationRecord {
        let conversation = ConversationRecord(id: sampleConversationID, agentAddress: testAgentAddress, title: title)
        conversation.messages = messages
        return conversation
    }
}
