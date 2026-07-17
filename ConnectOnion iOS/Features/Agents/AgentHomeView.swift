import SwiftData
import SwiftUI
import UIKit

/// One agent's home: its identity, a "New chat" action, and the list of conversations that belong to
/// this agent. Pushed when an agent is tapped in the agent-centric navigation (P4).
struct AgentHomeView: View {
    @Environment(ChatSessionStore.self) private var chatSessions

    var agent: AgentConfigRecord
    var info: AgentInfo?
    var conversations: [ConversationRecord]
    var onNewChat: () -> Void
    var onOpenConversation: (ConversationRecord) -> Void
    var onRenameConversation: (ConversationRecord, String) -> Void
    var onRequestDeleteConversation: (ConversationRecord) -> Void
    var onDeleteConversation: (ConversationRecord) -> Void

    @State private var showingInfo = false
    @State private var searchQuery = ""

    private var filteredConversations: [ConversationRecord] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let base = query.isEmpty
            ? conversations
            : conversations.filter { $0.title.localizedCaseInsensitiveContains(query) }
        // Pinned chats first (most recent pin on top), everything else in its usual order.
        let pinned = base.filter { $0.pinnedAt != nil }
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        return pinned + base.filter { $0.pinnedAt == nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            VStack(spacing: 14) {
                newChatButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if !conversations.isEmpty {
                    FloatingSearchBar(
                        text: $searchQuery,
                        prompt: "Search",
                        accessibilityID: AccessibilityID.chatSearchField
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(Color.appCanvas.ignoresSafeArea())
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
                } else if filteredConversations.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                        .padding(.top, 60)
                } else {
                    SidebarSectionTitle(title: "Chats")
                    LazyVStack(spacing: 10) {
                        ForEach(filteredConversations) { conversation in
                            // No container-level id here — the row applies its own id to its select
                            // button (a container id shadows onto the inner menu button).
                            ConversationSidebarRow(
                                conversation: conversation,
                                agentName: agent.displayName(info: info),
                                isSelected: false,
                                isGenerating: chatSessions.isGeneratingReply(for: conversation.id),
                                onSelect: { onOpenConversation(conversation) },
                                onRename: { onRenameConversation(conversation, $0) },
                                onRequestDelete: { onRequestDeleteConversation(conversation) },
                                onDelete: { onDeleteConversation(conversation) }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 150) // clear the floating New Chat button + search bar
            // Tapping empty space dismisses the keyboard (which also commits an in-progress inline
            // rename via focus loss) — same affordance as the agent list.
            .contentShape(.rect)
            .onTapGesture { dismissKeyboard() }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        .environment(ChatSessionStore())
        .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}
