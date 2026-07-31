//
//  AgentSidebarRow.swift
//
//  Purpose: Implements AgentSidebarRow for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AppShellView, ConnectOnionWordmark, ConversationSidebarRow, EmptyStateHero.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct AgentSidebarRow: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var isSelected: Bool
    var onSelect: () -> Void
    var onNewChat: () -> Void
    var onRename: (String) -> Void
    var onDelete: () -> Void

    @State private var isRenaming = false
    @State private var draftName = ""

    var body: some View {
        HStack(spacing: 8) {
            if isRenaming {
                HStack(spacing: 12) {
                    AgentAvatar(title: displayName, connectionPhase: connectionPhase)
                    InlineRenameField(
                        text: $draftName,
                        accessibilityID: AccessibilityID.agentRenameField,
                        onCommit: commitRename
                    )
                    Spacer(minLength: 0)
                }
            } else {
                Button(action: onSelect) {
                    HStack(spacing: 12) {
                        AgentAvatar(title: displayName, connectionPhase: connectionPhase)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .brandSerifFont(.body, weight: .semibold)
                                .lineLimit(1)

                            if let model = info?.model, !model.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "cpu").imageScale(.small)
                                    Text(model).lineLimit(1)
                                }
                                .appFont(.footnote)
                                .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 5) {
                                AgentStatusLabel(
                                    connectionPhase: connectionPhase,
                                    showsActivityIndicator: false
                                )
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(AgentAddress(rawValue: agent.address)?.shortDisplay ?? agent.address)
                                    .foregroundStyle(.tertiary)
                            }
                            .appFont(.footnote)
                            .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        if isPinned {
                            Image(systemName: "pin.fill")
                                .appFont(.caption)
                                .foregroundStyle(Color.onion.opacity(0.7))
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(displayName), \(connectionPhase.accessibilityLabel)")
                .accessibilityIdentifier(AccessibilityID.agent(agent.address))
                .contextMenu {
                    actions
                }

                Menu {
                    actions
                } label: {
                    Image(systemName: "ellipsis")
                        .appFont(.body, weight: .semibold)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                // No system press platter behind the glyph — it flashed as a stray square on the card.
                .menuStyle(.button)
                .buttonStyle(QuietPressButtonStyle())
                .accessibilityLabel("Agent Actions")
                .accessibilityIdentifier(AccessibilityID.agentActionsButton)
            }
        }
        .padding(14)
        .frame(minHeight: 64)
        .sidebarCard(isSelected: isSelected, isPinned: isPinned)
        .contentShape(.rect)
    }

    private var displayName: String {
        agent.displayName(info: info)
    }

    private var isPinned: Bool {
        agent.pinnedAt != nil
    }

    private var connectionPhase: AgentConnectionPhase {
        AgentConnectionPhase(info: info)
    }

    @ViewBuilder
    private var actions: some View {
        Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin") { togglePin() }
        Button("Rename", systemImage: "pencil") { startRename() }
            .accessibilityIdentifier(AccessibilityID.renameAgentButton)
        Button("Delete Agent", systemImage: "trash", role: .destructive, action: onDelete)
            .accessibilityIdentifier(AccessibilityID.deleteAgentButton)
    }

    private func togglePin() {
        withAnimation(AppMotion.standard) {
            agent.pinnedAt = isPinned ? nil : .now
        }
    }

    private func startRename() {
        draftName = displayName
        isRenaming = true
    }

    private func commitRename() {
        guard isRenaming else { return }
        isRenaming = false
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != displayName {
            onRename(trimmed)
        }
    }
}

#Preview("Agent Row Selected") {
    AgentSidebarRow(
        agent: PreviewFixtures.sampleAgent,
        info: PreviewFixtures.sampleAgentInfo,
        isSelected: true,
        onSelect: {},
        onNewChat: {},
        onRename: { _ in },
        onDelete: {}
    )
    .padding()
}

#Preview("Agent Row Offline") {
    let agent = PreviewFixtures.sampleAgent
    let info = AgentInfo(address: agent.address, name: "OpenOnion", online: false)
    AgentSidebarRow(agent: agent, info: info, isSelected: false, onSelect: {}, onNewChat: {}, onRename: { _ in }, onDelete: {})
        .padding()
}

#Preview("Agent Row With Remote Profile") {
    let agent = AgentConfigRecord(address: PreviewFixtures.testAgentAddress, alias: "A1")
    let info = AgentInfo(address: agent.address, name: "OpenOnion", online: true)
    AgentSidebarRow(agent: agent, info: info, isSelected: true, onSelect: {}, onNewChat: {}, onRename: { _ in }, onDelete: {})
        .padding()
}
