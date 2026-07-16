import SwiftUI
import UIKit

/// The root of the agent-centric navigation (P4): the main screen lists agents only. Tapping an agent
/// pushes its home (its chat list). No flat global "Chats" list here.
struct AgentListView: View {
    var agents: [AgentConfigRecord]
    var infoByAddress: [String: AgentInfo]
    var onSelectAgent: (AgentConfigRecord) -> Void
    var onAddAgent: () -> Void
    var onSettings: () -> Void
    var onRenameAgent: (AgentConfigRecord, String) -> Void
    var onDeleteAgent: (AgentConfigRecord) -> Void
    var onRefresh: () async -> Void

    @State private var feedbackTrigger = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if agents.isEmpty {
                    EmptyStateHero {
                        feedbackTrigger += 1
                        onAddAgent()
                    }
                    .frame(minHeight: 520)
                    .padding(.vertical, 48)
                    .transition(AppMotion.panelTransition)
                } else {
                    SidebarSectionTitle(title: "Agents")

                    ForEach(agents) { agent in
                        AgentSidebarRow(
                            agent: agent,
                            info: infoByAddress[agent.address],
                            isSelected: false,
                            onSelect: { onSelectAgent(agent) },
                            onNewChat: { onSelectAgent(agent) },
                            onRename: { newName in
                                feedbackTrigger += 1
                                onRenameAgent(agent, newName)
                            },
                            onDelete: {
                                feedbackTrigger += 1
                                onDeleteAgent(agent)
                            }
                        )
                        .transition(AppMotion.panelTransition)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(.rect)
            .onTapGesture { dismissKeyboard() }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .refreshable { await onRefresh() }
        .animation(AppMotion.standard, value: agents.map(\.address))
        .accessibilityIdentifier(AccessibilityID.sidebar)
        .overlay(alignment: .bottomTrailing) {
            if !agents.isEmpty {
                newAgentButton
                    .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") {
                    feedbackTrigger += 1
                    onSettings()
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier(AccessibilityID.settingsButton)
            }
            ToolbarItem(placement: .principal) {
                if !agents.isEmpty {
                    ConnectOnionWordmark()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private var newAgentButton: some View {
        Button {
            feedbackTrigger += 1
            onAddAgent()
        } label: {
            Label("New Agent", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Color.onion, in: .capsule)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New Agent")
        .accessibilityIdentifier(AccessibilityID.addAgentButton)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
