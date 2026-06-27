import SwiftUI

struct SidebarView: View {
    var agents: [AgentConfigRecord]
    var conversations: [ConversationRecord]
    var infoByAddress: [String: AgentInfo]
    @Binding var selectedAgentAddress: String?
    @Binding var selectedConversationID: UUID?
    var onNewChat: (AgentConfigRecord) -> Void
    var onNewConversation: () -> Void
    var onAddAgent: () -> Void
    var onRenameAgent: (AgentConfigRecord) -> Void
    var onDeleteAgent: (AgentConfigRecord) -> Void
    var onDeleteConversation: (ConversationRecord) -> Void
    var onSettings: () -> Void
    var onOpenDetail: () -> Void
    var onRefresh: () async -> Void

    @State private var feedbackTrigger = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if agents.isEmpty && conversations.isEmpty {
                    SidebarEmptyState {
                        tick()
                        onAddAgent()
                    }
                    .transition(AppMotion.panelTransition)
                }

                if !agents.isEmpty {
                    SidebarSectionTitle(title: "Agents")
                        .transition(AppMotion.panelTransition)

                    ForEach(agents) { agent in
                        AgentSidebarRow(
                            agent: agent,
                            info: infoByAddress[agent.address],
                            isSelected: selectedAgentAddress == agent.address && selectedConversationID == nil,
                            onSelect: { select(agent: agent) },
                            onNewChat: {
                                tick()
                                onNewChat(agent)
                            },
                            onRename: {
                                tick()
                                onRenameAgent(agent)
                            },
                            onDelete: {
                                tick()
                                onDeleteAgent(agent)
                            }
                        )
                        .transition(AppMotion.panelTransition)
                    }
                }

                if !conversations.isEmpty {
                    SidebarSectionTitle(title: "Chats")
                        .transition(AppMotion.panelTransition)

                    ForEach(conversations) { conversation in
                        ConversationSidebarRow(
                            conversation: conversation,
                            agentName: agentName(for: conversation.agentAddress),
                            isSelected: selectedConversationID == conversation.id,
                            onSelect: { select(conversation: conversation) },
                            onDelete: {
                                tick()
                                onDeleteConversation(conversation)
                            }
                        )
                        .accessibilityIdentifier(AccessibilityID.conversation(conversation.id))
                        .transition(AppMotion.panelTransition)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await onRefresh()
        }
        .accessibilityIdentifier(AccessibilityID.sidebar)
        .animation(AppMotion.standard, value: agents.map(\.address))
        .animation(AppMotion.standard, value: conversations.map(\.id))
        .navigationTitle("ConnectOnion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") {
                    tick()
                    onSettings()
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier(AccessibilityID.settingsButton)
            }
            .visibilityPriority(.high)
            .contentMarginsRemoved()

            ToolbarItem(placement: .principal) {
                Text("ConnectOnion")
                    .font(.headline)
                    .lineLimit(1)
            }
        }
        .toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar)
        .toolbarMinimizationSafeAreaAdjustment(.enabled, for: .navigationBar)
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            if !agents.isEmpty {
                NewChatFloatingButton {
                    tick()
                    onNewConversation()
                }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
                .transition(AppMotion.panelTransition)
            }
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .background(.background)
    }

    private func select(agent: AgentConfigRecord) {
        tick()
        selectedAgentAddress = agent.address
        selectedConversationID = nil
        onOpenDetail()
    }

    private func select(conversation: ConversationRecord) {
        tick()
        selectedAgentAddress = conversation.agentAddress
        selectedConversationID = conversation.id
        onOpenDetail()
    }

    private func tick() {
        feedbackTrigger += 1
    }

    private func agentName(for address: String) -> String {
        if let agent = agents.first(where: { $0.address == address }) {
            return agent.displayName(info: infoByAddress[address])
        }
        return AgentAddress(rawValue: address)?.shortDisplay ?? address
    }
}

private struct NewChatFloatingButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
        }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
            .contentShape(.circle)
            .accessibilityLabel("New Chat")
            .accessibilityIdentifier(AccessibilityID.newChatButton)
    }
}

private struct SidebarEmptyState: View {
    var onAddAgent: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ConnectOnionLogoMark()

            Text("ConnectOnion")
                .font(.title.bold())

            Button("Add Agent", systemImage: "plus", action: onAddAgent)
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier(AccessibilityID.addAgentButton)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 520)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }
}

#Preview("Sidebar Loaded") {
    SidebarView(
        agents: [PreviewFixtures.sampleAgent],
        conversations: [PreviewFixtures.sampleConversation],
        infoByAddress: [PreviewFixtures.testAgentAddress: PreviewFixtures.sampleAgentInfo],
        selectedAgentAddress: .constant(PreviewFixtures.testAgentAddress),
        selectedConversationID: .constant(nil),
        onNewChat: { _ in },
        onNewConversation: {},
        onAddAgent: {},
        onRenameAgent: { _ in },
        onDeleteAgent: { _ in },
        onDeleteConversation: { _ in },
        onSettings: {},
        onOpenDetail: {},
        onRefresh: {}
    )
}

#Preview("Sidebar Empty") {
    SidebarView(
        agents: [],
        conversations: [],
        infoByAddress: [:],
        selectedAgentAddress: .constant(nil),
        selectedConversationID: .constant(nil),
        onNewChat: { _ in },
        onNewConversation: {},
        onAddAgent: {},
        onRenameAgent: { _ in },
        onDeleteAgent: { _ in },
        onDeleteConversation: { _ in },
        onSettings: {},
        onOpenDetail: {},
        onRefresh: {}
    )
}
