//
//  AgentListView.swift
//
//  Purpose: Implements AgentListView for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow, EmptyStateHero.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI
import UIKit

/// The root of the agent-centric navigation (P4): the main screen lists agents only. Tapping an agent
/// pushes its home (its chat list). No flat global "Chats" list here.
struct AgentListView: View {
    var agents: [AgentConfigRecord]
    var infoByAddress: [String: AgentInfo]
    var zoomNamespace: Namespace.ID
    var onSelectAgent: (AgentConfigRecord) -> Void
    var onAddAgent: () -> Void
    var onSettings: () -> Void
    var onRenameAgent: (AgentConfigRecord, String) -> Void
    var onDeleteAgent: (AgentConfigRecord) -> Void
    var onRefresh: () async -> Void

    @State private var feedbackTrigger = 0
    @State private var searchQuery = ""

    private var filteredAgents: [AgentConfigRecord] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let base: [AgentConfigRecord]
        if query.isEmpty {
            base = agents
        } else {
            base = agents.filter { agent in
                let info = infoByAddress[agent.address]
                return agent.displayName(info: info).localizedCaseInsensitiveContains(query)
                    || (info?.model?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        // Pinned agents first (most recent pin on top), everything else in its usual order.
        let pinned = base.filter { $0.pinnedAt != nil }
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        return pinned + base.filter { $0.pinnedAt == nil }
    }

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
                } else if filteredAgents.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                        .padding(.top, 120)
                } else {
                    SidebarSectionTitle(title: "Agents")

                    ForEach(filteredAgents) { agent in
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
                        // Source anchor for the zoom push into this agent's home.
                        .matchedTransitionSource(id: agent.address, in: zoomNamespace)
                        .transition(AppMotion.panelTransition)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 140) // clear the floating button + search bar
            .frame(maxWidth: .infinity, alignment: .top)
            .contentShape(.rect)
            .onTapGesture { dismissKeyboard() }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .refreshable { await onRefresh() }
        .animation(AppMotion.standard, value: agents.map(\.address))
        .animation(AppMotion.quick, value: filteredAgents.map(\.address))
        .accessibilityIdentifier(AccessibilityID.sidebar)
        .overlay(alignment: .bottom) {
            if !agents.isEmpty {
                VStack(spacing: 14) {
                    newAgentButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    FloatingSearchBar(
                        text: $searchQuery,
                        prompt: "Search",
                        accessibilityID: AccessibilityID.agentSearchField
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Settings manages agents/appearance — no need on the new-user welcome (no agents yet).
            if !agents.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") {
                        feedbackTrigger += 1
                        onSettings()
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier(AccessibilityID.settingsButton)
                }
            }
            ToolbarItem(placement: .principal) {
                if !agents.isEmpty {
                    ConnectOnionWordmark()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .background(Color.appCanvas.ignoresSafeArea())
    }

    private var newAgentButton: some View {
        Button {
            feedbackTrigger += 1
            onAddAgent()
        } label: {
            Label("New Agent", systemImage: "plus")
                .appFont(.headline)
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
