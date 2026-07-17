import Factory
import SwiftUI

struct SettingsView: View {
    var agents: [AgentConfigRecord] = []
    var infoByAddress: [String: AgentInfo] = [:]
    var onAddAgent: (() -> Void)? = nil
    var onDeleteAgent: (AgentConfigRecord) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    @AppStorage(CustomInstructionsStorage.storageKey) private var customInstructions = ""
    @State private var showingInfo = false
    @State private var feedbackTrigger = 0
    @State private var customInstructionsDraft = ""
    @State private var hasLoadedCustomInstructionsDraft = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                } header: {
                    Text("Agents")
                        .font(AppFont.sectionSerif)
                        .textCase(nil)
                }
                // Match the warm card surface used across the app (the system grouped row color is
                // cool/bluish in dark and clashes with the warm canvas).
                .listRowBackground(Color.appElevated)

                Section {
                    AppearancePicker(selection: $appearance)
                        .padding(.vertical, 6)
                } header: {
                    Text("Appearance")
                        .font(AppFont.sectionSerif)
                        .textCase(nil)
                }
                .listRowBackground(Color.appElevated)

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom instructions")
                                .font(.headline)
                            Text("Sent with every message to every agent.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ZStack(alignment: .topLeading) {
                            if customInstructionsDraft.isEmpty {
                                Text("Add preferences for how agents should respond")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $customInstructionsDraft)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .accessibilityLabel("Custom instructions")
                                .accessibilityIdentifier(AccessibilityID.customInstructionsEditor)
                        }
                        .frame(minHeight: 140)
                        .background(Color.appElevated2, in: .rect(cornerRadius: 12))

                        HStack {
                            Spacer()
                            Button("Save", action: saveCustomInstructions)
                                .buttonStyle(.borderedProminent)
                                .disabled(!hasCustomInstructionsChanges)
                                .accessibilityIdentifier(AccessibilityID.saveCustomInstructionsButton)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Personalisation")
                        .font(AppFont.sectionSerif)
                        .textCase(nil)
                }
                .listRowBackground(Color.appElevated)

                Section {
                } footer: {
                    Text("Powered by OpenOnion")
                        .font(.system(.callout, design: .serif).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appGroupedCanvas)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(AppFont.wordmark)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("About", systemImage: "info.circle") { showingInfo = true }
                        .labelStyle(.iconOnly)
                        .popover(isPresented: $showingInfo) {
                            SettingsInfoView(appVersion: appVersion)
                                .presentationCompactAdaptation(.popover)
                        }
                }
            }
            .sensoryFeedback(.selection, trigger: feedbackTrigger)
            .onAppear {
                guard !hasLoadedCustomInstructionsDraft else { return }
                customInstructionsDraft = customInstructions
                hasLoadedCustomInstructionsDraft = true
            }
        }
        .presentationBackground(Color.appGroupedCanvas)
    }

    private var normalizedCustomInstructionsDraft: String {
        CustomInstructionsStorage.normalized(customInstructionsDraft)
    }

    private var hasCustomInstructionsChanges: Bool {
        normalizedCustomInstructionsDraft != customInstructions
    }

    private func saveCustomInstructions() {
        customInstructions = normalizedCustomInstructionsDraft
        customInstructionsDraft = customInstructions
        feedbackTrigger += 1
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

enum CustomInstructionsStorage {
    static let storageKey = "customInstructions"

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    .font(AppFont.rowName)
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
    var appVersion: String

    @Injected(\.identityStore) private var identityStore: IdentityProviding
    @State private var identity: ClientIdentity?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            infoRow("Version", value: appVersion)
            Divider()
            infoRow("Relay server", value: "oo.openonion.ai")
            if let identity {
                Divider()
                infoRow("Your identity", value: identity.shortAddress)
            }
        }
        .frame(width: 280)
        .padding(.vertical, 6)
        .onAppear { identity = try? identityStore.currentIdentity }
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
