import SwiftUI

struct NewConversationSheet: View {
    var agents: [AgentConfigRecord]
    var infoByAddress: [String: AgentInfo]
    var initialAgentAddress: String?
    var onStart: (AgentConfigRecord, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedAddress: String
    @State private var prompt = ""
    @State private var feedbackTrigger = 0

    init(
        agents: [AgentConfigRecord],
        infoByAddress: [String: AgentInfo],
        initialAgentAddress: String?,
        onStart: @escaping (AgentConfigRecord, String) -> Void
    ) {
        self.agents = agents
        self.infoByAddress = infoByAddress
        self.initialAgentAddress = initialAgentAddress
        self.onStart = onStart
        _selectedAddress = State(initialValue: initialAgentAddress ?? agents.first?.address ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        SidebarSectionTitle(title: "Agent")

                        ForEach(agents) { agent in
                            Button {
                                feedbackTrigger += 1
                                withAnimation(AppMotion.quick) {
                                    selectedAddress = agent.address
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    AgentAvatar(title: displayName(for: agent), online: infoByAddress[agent.address]?.online)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(displayName(for: agent))
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if let remoteProfileName = agent.remoteProfileName(info: infoByAddress[agent.address]) {
                                            AgentProfileNameLabel(name: remoteProfileName)
                                        }

                                        Text(AgentAddress(rawValue: agent.address)?.shortDisplay ?? agent.address)
                                            .font(.footnote.monospaced())
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)

                                    Image(systemName: selectedAddress == agent.address ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedAddress == agent.address ? Color.accentColor : Color.secondary)
                                }
                                .padding(12)
                                .background(selectedAddress == agent.address ? Color.primary.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 18))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AccessibilityID.newChatAgent(agent.address))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 10) {
                    TextField("First message", text: $prompt, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .tint(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 16))
                        .submitLabel(.send)
                        .onSubmit(start)
                        .accessibilityIdentifier(AccessibilityID.newChatPromptField)

                    Button(startButtonTitle, systemImage: startButtonIcon, action: start)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .buttonStyle(.glassProminent)
                        .disabled(selectedAgent == nil)
                        .accessibilityIdentifier(AccessibilityID.newChatStartButton)
                }
                .padding(14)
                .glassSurface(cornerRadius: 28, isInteractive: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.newChatSheet)
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private var selectedAgent: AgentConfigRecord? {
        agents.first { $0.address == selectedAddress }
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var startButtonTitle: String {
        trimmedPrompt.isEmpty ? "Open Chat" : "Start Chat"
    }

    private var startButtonIcon: String {
        trimmedPrompt.isEmpty ? "bubble.left.and.bubble.right" : "arrow.up"
    }

    private func displayName(for agent: AgentConfigRecord) -> String {
        agent.displayName(info: infoByAddress[agent.address])
    }

    private func start() {
        guard let selectedAgent else { return }
        feedbackTrigger += 1
        onStart(selectedAgent, trimmedPrompt)
        dismiss()
    }
}

#Preview("New Conversation") {
    NewConversationSheet(
        agents: [PreviewFixtures.sampleAgent],
        infoByAddress: [PreviewFixtures.testAgentAddress: PreviewFixtures.sampleAgentInfo],
        initialAgentAddress: PreviewFixtures.testAgentAddress,
        onStart: { _, _ in }
    )
}

#Preview("New Conversation Empty Prompt") {
    NewConversationSheet(
        agents: [PreviewFixtures.sampleAgent],
        infoByAddress: [:],
        initialAgentAddress: nil,
        onStart: { _, _ in }
    )
}

#Preview("New Conversation With Remote Profile") {
    let agent = AgentConfigRecord(address: PreviewFixtures.testAgentAddress, alias: "A1")
    let info = AgentInfo(address: PreviewFixtures.testAgentAddress, name: "OpenOnion", online: true)
    NewConversationSheet(
        agents: [agent],
        infoByAddress: [PreviewFixtures.testAgentAddress: info],
        initialAgentAddress: PreviewFixtures.testAgentAddress,
        onStart: { _, _ in }
    )
}
