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
                    AgentAvatar(title: displayName, online: info?.online)
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
                        AgentAvatar(title: displayName, online: info?.online)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .font(AppFont.rowName)
                                .lineLimit(1)

                            if let model = info?.model, !model.isEmpty {
                                Label {
                                    Text(model).lineLimit(1)
                                } icon: {
                                    Image(systemName: "cpu").imageScale(.small)
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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

                Menu {
                    actions
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
        }
        .padding(14)
        .frame(minHeight: 64)
        .sidebarCard(isSelected: isSelected)
        .contentShape(.rect)
    }

    private var displayName: String {
        agent.displayName(info: info)
    }

    @ViewBuilder
    private var actions: some View {
        Button("Rename", systemImage: "pencil") { startRename() }
            .accessibilityIdentifier(AccessibilityID.renameAgentButton)
        Button("Delete Agent", systemImage: "trash", role: .destructive, action: onDelete)
            .accessibilityIdentifier(AccessibilityID.deleteAgentButton)
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
