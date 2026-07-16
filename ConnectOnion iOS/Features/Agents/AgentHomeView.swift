import SwiftData
import SwiftUI

/// One agent's home: its identity, a "New chat" action, and the list of conversations that belong to
/// this agent. Pushed when an agent is tapped in the agent-centric navigation (P4).
struct AgentHomeView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var conversations: [ConversationRecord]
    var onNewChat: () -> Void
    var onOpenConversation: (ConversationRecord) -> Void
    var onRenameConversation: (ConversationRecord, String) -> Void
    var onRequestDeleteConversation: (ConversationRecord) -> Void
    var onDeleteConversation: (ConversationRecord) -> Void

    @State private var showingInfo = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
            newChatButton
                .padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Agent Info", systemImage: "info.circle") { showingInfo = true }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier(AccessibilityID.agentInfoButton)
                    .popover(isPresented: $showingInfo) {
                        AgentInfoPopover(agent: agent, info: info)
                            .presentationCompactAdaptation(.popover)
                    }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AgentHeroView(agent: agent, info: info)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                if conversations.isEmpty {
                    emptyState
                } else {
                    SidebarSectionTitle(title: "Chats")
                    LazyVStack(spacing: 10) {
                        ForEach(conversations) { conversation in
                            ConversationSidebarRow(
                                conversation: conversation,
                                agentName: agent.displayName(info: info),
                                isSelected: false,
                                onSelect: { onOpenConversation(conversation) },
                                onRename: { onRenameConversation(conversation, $0) },
                                onRequestDelete: { onRequestDeleteConversation(conversation) },
                                onDelete: { onDeleteConversation(conversation) }
                            )
                            .accessibilityIdentifier(AccessibilityID.conversation(conversation.id))
                        }
                    }
                }
            }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 100) // clear the floating New Chat button
        }
    }

    /// Matches the "+ New Agent" floating button on the agent list — same shape, size, and position.
    private var newChatButton: some View {
        Button(action: onNewChat) {
            Label("New Chat", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Color.onion, in: .capsule)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.newChatInAgentButton)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No chats yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a new chat with \(agent.displayName(info: info)).")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

#Preview("Agent Home") {
    let _ = PreviewFixtures.installMockDependencies()
    let container = PreviewFixtures.seededContainer()
    if let agent = try? container.mainContext.fetch(FetchDescriptor<AgentConfigRecord>()).first {
        NavigationStack {
            AgentHomeView(
                agent: agent,
                info: agent.cachedInfo,
                conversations: [PreviewFixtures.sampleConversation],
                onNewChat: {},
                onOpenConversation: { _ in },
                onRenameConversation: { _, _ in },
                onRequestDeleteConversation: { _ in },
                onDeleteConversation: { _ in }
            )
        }
        .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}
