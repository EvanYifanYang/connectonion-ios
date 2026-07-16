import SwiftUI
import SwiftData

struct ChatScreen: View {
    let conversation: ConversationRecord
    let agent: AgentConfigRecord
    let info: AgentInfo?
    let initialInput: AgentInput?
    let onInitialInputConsumed: () -> Void

    @State private var viewModel: ChatViewModel

    init(
        conversation: ConversationRecord,
        agent: AgentConfigRecord,
        info: AgentInfo?,
        initialInput: AgentInput?,
        onInitialInputConsumed: @escaping () -> Void
    ) {
        self.conversation = conversation
        self.agent = agent
        self.info = info
        self.initialInput = initialInput
        self.onInitialInputConsumed = onInitialInputConsumed
        _viewModel = State(initialValue: ChatViewModel(conversation: conversation, agent: agent.config))
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatMessageList(
                items: viewModel.items,
                pendingAskUser: viewModel.pendingAskUser,
                pendingApproval: viewModel.pendingApproval,
                pendingOnboard: viewModel.pendingOnboard,
                pendingPlanReview: viewModel.pendingPlanReview,
                onAskUserResponse: viewModel.respondToAskUser,
                onApprovalResponse: viewModel.respondToApproval,
                onOnboardSubmit: viewModel.submitOnboard,
                onPlanReviewResponse: viewModel.respondToPlanReview
            )

            if let errorMessage = viewModel.errorMessage {
                ChatErrorBanner(message: errorMessage, onReconnect: viewModel.reconnect)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(AppMotion.panelTransition)
            }

            if viewModel.shouldShowFirstPromptSuggestions {
                PromptSuggestionStrip(
                    suggestions: AgentPromptSuggestions.defaults,
                    onSelect: { viewModel.send($0) }
                )
                .accessibilityIdentifier(AccessibilityID.suggestionStrip)
                .padding(.bottom, 8)
                .transition(AppMotion.panelTransition)
            }

            ChatInputBar(
                placeholder: "Message \(displayName)",
                isRunning: viewModel.shouldShowStopButton,
                acceptedInputs: info?.acceptedInputs,
                skills: info?.skills ?? [],
                onSend: { viewModel.send($0, images: $1, files: $2) },
                onStop: viewModel.stop
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        // No chat title + a transparent bar, so the transcript runs to the top (Claude-style).
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .animation(AppMotion.standard, value: viewModel.errorMessage != nil)
        .animation(AppMotion.standard, value: viewModel.shouldShowFirstPromptSuggestions)
        .task(id: conversation.id) {
            guard let initialInput else { return }
            viewModel.send(initialInput.prompt, images: initialInput.images, files: initialInput.files)
            onInitialInputConsumed()
        }
    }

    private var displayName: String {
        agent.displayName(info: info)
    }
}

#Preview("Chat Screen") {
    let _ = PreviewFixtures.installMockDependencies()
    let container = PreviewFixtures.seededContainer()
    let context = container.mainContext
    let agent = try? context.fetch(FetchDescriptor<AgentConfigRecord>()).first
    let conversation = try? context.fetch(FetchDescriptor<ConversationRecord>()).first
    if let agent, let conversation {
        ChatScreen(
            conversation: conversation,
            agent: agent,
            info: agent.cachedInfo,
            initialInput: nil,
            onInitialInputConsumed: {}
        )
            .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}
