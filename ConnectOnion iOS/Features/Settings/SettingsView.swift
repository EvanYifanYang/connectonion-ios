import Factory
import SwiftUI

struct SettingsView: View {
    var agents: [AgentConfigRecord] = []
    var infoByAddress: [String: AgentInfo] = [:]
    var onAddAgent: (() -> Void)? = nil
    var onDeleteAgent: (AgentConfigRecord) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Injected(\.identityStore) private var identityStore: IdentityProviding

    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    @State private var identity: ClientIdentity?
    @State private var errorMessage: String?
    @State private var confirmingRegenerate = false
    @State private var feedbackTrigger = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Agents") {
                    ForEach(agents) { agent in
                        NavigationLink {
                            AgentDetailView(agent: agent, info: infoByAddress[agent.address]) {
                                onDeleteAgent(agent)
                            }
                        } label: {
                            AgentSettingsRow(agent: agent, info: infoByAddress[agent.address])
                        }
                    }

                    if let onAddAgent {
                        Button("Add Agent", systemImage: "plus") {
                            feedbackTrigger += 1
                            onAddAgent()
                        }
                        .accessibilityIdentifier(AccessibilityID.addAgentButton)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    if let identity {
                        LabeledContent("Your identity") {
                            Text(identity.shortAddress)
                                .font(.footnote.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    LabeledContent("Relay server", value: "oo.openonion.ai")
                    LabeledContent("Version", value: appVersion)

                    Button("Regenerate Identity", systemImage: "key", role: .destructive) {
                        confirmingRegenerate = true
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Regenerate Identity", isPresented: $confirmingRegenerate) {
                Button("Regenerate", role: .destructive, action: regenerate)
                Button("Cancel", role: .cancel) {}
            }
            .task {
                loadIdentity()
            }
            .sensoryFeedback(.selection, trigger: feedbackTrigger)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func loadIdentity() {
        do {
            identity = try identityStore.currentIdentity
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func regenerate() {
        do {
            identity = try identityStore.regenerateIdentity()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AgentSettingsRow: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?

    var body: some View {
        HStack(spacing: 12) {
            AgentAvatar(title: agent.displayName(info: info), online: info?.online)

            VStack(alignment: .leading, spacing: 3) {
                Text(agent.displayName(info: info))
                    .font(.body)
                    .lineLimit(1)
                Text(endpointText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            AgentStatusLabel(online: info?.online)
        }
    }

    private var endpointText: String {
        if let endpoint = agent.preferredEndpoint {
            return endpoint.absoluteString
        }
        return AgentAddress(rawValue: agent.address)?.shortDisplay ?? agent.address
    }
}

#Preview {
    let _ = PreviewFixtures.installMockDependencies()
    SettingsView(
        agents: [PreviewFixtures.sampleAgent],
        infoByAddress: [PreviewFixtures.testAgentAddress: PreviewFixtures.sampleAgentInfo],
        onAddAgent: {},
        onDeleteAgent: { _ in }
    )
}
