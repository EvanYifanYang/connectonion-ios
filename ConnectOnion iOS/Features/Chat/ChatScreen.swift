//
//  ChatScreen.swift
//
//  Purpose: Implements ChatScreen for the Features/Chat module.
//  Collaborates with: ChatErrorBanner, ChatHeaderView, ChatItemView, ChatMessageList, ChatTimeline, ChatViewModel.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI
import SwiftData

struct ChatScreen: View {
    let conversation: ConversationRecord
    let agent: AgentConfigRecord
    let info: AgentInfo?
    let initialInput: AgentInput?
    let onInitialInputConsumed: () -> Void

    let viewModel: ChatViewModel
    let sessionStore: ChatSessionStore

    @State private var showingInfo = false

    init(
        conversation: ConversationRecord,
        agent: AgentConfigRecord,
        info: AgentInfo?,
        initialInput: AgentInput?,
        onInitialInputConsumed: @escaping () -> Void,
        viewModel: ChatViewModel,
        sessionStore: ChatSessionStore
    ) {
        self.conversation = conversation
        self.agent = agent
        self.info = info
        self.initialInput = initialInput
        self.onInitialInputConsumed = onInitialInputConsumed
        self.viewModel = viewModel
        self.sessionStore = sessionStore
    }

    var body: some View {
        ChatMessageList(
            items: viewModel.items,
            pendingAskUser: viewModel.pendingAskUser,
            pendingApproval: viewModel.pendingApproval,
            pendingOnboard: viewModel.pendingOnboard,
            pendingPlanReview: viewModel.pendingPlanReview,
            onAskUserResponse: viewModel.respondToAskUser,
            onApprovalResponse: viewModel.respondToApproval,
            onOnboardSubmit: viewModel.submitOnboard,
            onPlanReviewResponse: viewModel.respondToPlanReview,
            onRegenerate: viewModel.regenerate(replyID:),
            responseModel: viewModel.lastResponseModel,
            isAgentRunning: viewModel.shouldShowStopButton,
            streamingMessageID: viewModel.streamingMessageID,
            onStreamComplete: viewModel.markStreamingComplete
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposerInset(
                errorMessage: viewModel.errorMessage,
                placeholder: "Reply to ConnectOnion Agent",
                isRunning: viewModel.shouldShowStopButton,
                acceptedInputs: info?.acceptedInputs,
                skills: info?.skills ?? [],
                onSend: { viewModel.send($0, images: $1, files: $2) },
                onStop: viewModel.stop,
                onReconnect: viewModel.reconnect
            )
        }
        .background(Color.appCanvas.ignoresSafeArea())
        // Keep the transparent bar, but fade the transcript out under the status bar / back button so
        // scrolled content doesn't clash with them.
        .overlay(alignment: .top) {
            LinearGradient(
                stops: [
                    .init(color: Color.appCanvas, location: 0),
                    .init(color: Color.appCanvas, location: 0.55),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 92)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        // No chat title + a transparent bar, so the transcript runs to the top (Claude-style).
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .animation(AppMotion.standard, value: viewModel.errorMessage != nil)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Conversation Info", systemImage: "info.circle") {
                    showingInfo = true
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier(AccessibilityID.agentInfoButton)
                .popover(isPresented: $showingInfo) {
                    AgentInfoPopover(
                        agent: agent,
                        info: info,
                        contextPercent: viewModel.contextPercent
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }
        }
        .onAppear {
            viewModel.prepareForPresentation()
            sessionStore.conversationDidAppear(conversation)
            // Re-attach to a turn that was left running when the app was killed/backgrounded.
            viewModel.resumeIfInterrupted()
        }
        .onDisappear {
            sessionStore.conversationDidDisappear(conversation.id)
        }
        .task(id: conversation.id) {
            guard let initialInput else { return }
            viewModel.send(initialInput.prompt, images: initialInput.images, files: initialInput.files)
            onInitialInputConsumed()
        }
    }
}

private struct ChatComposerInset: View {
    var errorMessage: String?
    var placeholder: String
    var isRunning: Bool
    var acceptedInputs: AgentAcceptedInputs?
    var skills: [SkillInfo]
    var onSend: (String, [String], [FileAttachment]) -> Void
    var onStop: () -> Void
    var onReconnect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                ChatErrorBanner(message: errorMessage, onReconnect: onReconnect)
            }

            ChatInputBar(
                placeholder: placeholder,
                isRunning: isRunning,
                acceptedInputs: acceptedInputs,
                skills: skills,
                onSend: onSend,
                onStop: onStop
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.appCanvas)
    }
}

#Preview("Chat Screen") {
    let _ = PreviewFixtures.installMockDependencies()
    let container = PreviewFixtures.seededContainer()
    let context = container.mainContext
    let agent = try? context.fetch(FetchDescriptor<AgentConfigRecord>()).first
    let conversation = try? context.fetch(FetchDescriptor<ConversationRecord>()).first
    if let agent, let conversation {
        let sessionStore = ChatSessionStore()
        ChatScreen(
            conversation: conversation,
            agent: agent,
            info: agent.cachedInfo,
            initialInput: nil,
            onInitialInputConsumed: {},
            viewModel: sessionStore.session(for: conversation, agent: agent.config),
            sessionStore: sessionStore
        )
            .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}
