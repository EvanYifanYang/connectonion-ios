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
    @State private var showingInfo = false
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("About", systemImage: "info.circle") { showingInfo = true }
                        .labelStyle(.iconOnly)
                }
            }
            .popover(isPresented: $showingInfo) {
                SettingsInfoView(
                    identity: identity,
                    appVersion: appVersion,
                    onRegenerate: {
                        showingInfo = false
                        confirmingRegenerate = true
                    }
                )
                .presentationCompactAdaptation(.popover)
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

private struct SettingsInfoView: View {
    var identity: ClientIdentity?
    var appVersion: String
    var onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            infoRow("Version", value: appVersion)
            Divider()
            infoRow("Relay server", value: "oo.openonion.ai")
            if let identity {
                Divider()
                infoRow("Your identity", value: identity.shortAddress)
            }
            Divider()
            Button("Regenerate Identity", systemImage: "key", role: .destructive, action: onRegenerate)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 280)
        .padding(.vertical, 6)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.callout)
            Spacer(minLength: 12)
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
