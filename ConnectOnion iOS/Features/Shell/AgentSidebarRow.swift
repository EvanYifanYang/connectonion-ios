import SwiftUI

struct AgentSidebarRow: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var isSelected: Bool
    var onSelect: () -> Void
    var onNewChat: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void

    @State private var isShowingActions = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    AgentAvatar(title: displayName, online: info?.online)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName)
                            .font(.body)
                            .lineLimit(1)

                        if let remoteProfileName {
                            AgentProfileNameLabel(name: remoteProfileName)
                        }

                        Text(AgentAddress(rawValue: agent.address)?.shortDisplay ?? agent.address)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(displayName)
            .accessibilityIdentifier(AccessibilityID.agent(agent.address))
            .contextMenu {
                actions
            }

            Button {
                isShowingActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Agent Actions")
            .accessibilityIdentifier(AccessibilityID.agentActionsButton)
        }
        .padding(10)
        .frame(minHeight: 62)
        .background(isSelected ? Color.primary.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 16))
        .contentShape(.rect)
        .confirmationDialog("Agent Actions", isPresented: $isShowingActions, titleVisibility: .visible) {
            actions
        }
    }

    private var displayName: String {
        agent.displayName(info: info)
    }

    private var remoteProfileName: String? {
        agent.remoteProfileName(info: info)
    }

    @ViewBuilder
    private var actions: some View {
        Button("New Chat", systemImage: "square.and.pencil", action: onNewChat)
        Button("Rename", systemImage: "pencil", action: onRename)
            .accessibilityIdentifier(AccessibilityID.renameAgentButton)
        Button("Delete Agent", systemImage: "trash", role: .destructive, action: onDelete)
            .accessibilityIdentifier(AccessibilityID.deleteAgentButton)
    }
}

#Preview("Agent Row Selected") {
    AgentSidebarRow(
        agent: PreviewFixtures.sampleAgent,
        info: PreviewFixtures.sampleAgentInfo,
        isSelected: true,
        onSelect: {},
        onNewChat: {},
        onRename: {},
        onDelete: {}
    )
    .padding()
}

#Preview("Agent Row Offline") {
    let agent = PreviewFixtures.sampleAgent
    let info = AgentInfo(address: agent.address, name: "OpenOnion", online: false)
    AgentSidebarRow(agent: agent, info: info, isSelected: false, onSelect: {}, onNewChat: {}, onRename: {}, onDelete: {})
        .padding()
}

#Preview("Agent Row With Remote Profile") {
    let agent = AgentConfigRecord(address: PreviewFixtures.testAgentAddress, alias: "A1")
    let info = AgentInfo(address: agent.address, name: "OpenOnion", online: true)
    AgentSidebarRow(agent: agent, info: info, isSelected: true, onSelect: {}, onNewChat: {}, onRename: {}, onDelete: {})
        .padding()
}
