//
//  SettingsView.swift
//
//  Purpose: Implements SettingsView for the Features/Settings module.
//  Collaborates with: AgentDetailView, AppearancePicker.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Factory
import SwiftUI

struct SettingsView: View {
    var agents: [AgentConfigRecord] = []
    var infoByAddress: [String: AgentInfo] = [:]
    var onAddAgent: (() -> Void)? = nil
    var onDeleteAgent: (AgentConfigRecord) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    @AppStorage(UIFontPreference.storageKey) private var uiFontPreference: UIFontPreference = .system
    @AppStorage(FontSizePreference.uiStorageKey) private var uiFontSize = FontSizePreference.defaultUI
    @AppStorage(CodeFontPreference.storageKey) private var codeFontPreference: CodeFontPreference = .sfMono
    @AppStorage(FontSizePreference.codeStorageKey) private var codeFontSize = FontSizePreference.defaultCode
    @State private var showingInfo = false
    @State private var feedbackTrigger = 0
    @State private var showAdvancedAppearance = false

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
                    Text("Agent configuration")
                        .brandSerifFont(.headline)
                        .textCase(nil)
                }
                // Match the warm card surface used across the app (the system grouped row color is
                // cool/bluish in dark and clashes with the warm canvas).
                .listRowBackground(Color.appElevated)

                Section {
                    AppearancePicker(selection: $appearance)
                        .padding(.vertical, 6)
                        // The default row separator insets from the leading edge, so it looked
                        // off-center under the full-width theme swatches. Span it edge to edge.
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

                    DisclosureGroup("Advanced", isExpanded: $showAdvancedAppearance) {
                        PreferencePickerRow(
                            title: "UI font",
                            selection: $uiFontPreference,
                            options: UIFontPreference.allCases,
                            label: \.displayName
                        )
                        .accessibilityIdentifier(AccessibilityID.uiFontPicker)

                        FontSizeRow(
                            title: "UI font size",
                            value: $uiFontSize,
                            defaultValue: FontSizePreference.defaultUI
                        )
                            .accessibilityIdentifier(AccessibilityID.uiFontSizeField)

                        PreferencePickerRow(
                            title: "Code font",
                            selection: $codeFontPreference,
                            options: CodeFontPreference.allCases,
                            label: \.displayName
                        )
                        .accessibilityIdentifier(AccessibilityID.codeFontPicker)

                        FontSizeRow(
                            title: "Code font size",
                            value: $codeFontSize,
                            defaultValue: FontSizePreference.defaultCode
                        )
                            .accessibilityIdentifier(AccessibilityID.codeFontSizeField)
                    }
                } header: {
                    Text("Appearance")
                        .brandSerifFont(.headline)
                        .textCase(nil)
                }
                .listRowBackground(Color.appElevated)

                Section {
                    NavigationLink {
                        PersonalizationView()
                    } label: {
                        Label("Personalization", systemImage: "person.text.rectangle")
                    }
                } header: {
                    Text("Personalization")
                        .brandSerifFont(.headline)
                        .textCase(nil)
                }
                .listRowBackground(Color.appElevated)

                Section {
                } footer: {
                    Text("Powered by OpenOnion")
                        .appFont(.callout, weight: .semibold)
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
                        .brandSerifFont(.title3, weight: .semibold)
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
        }
        .presentationBackground(Color.appGroupedCanvas)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct PersonalizationView: View {
    @AppStorage(PersonalityMode.storageKey) private var personality: PersonalityMode = .pragmatic
    @AppStorage(CustomInstructions.storageKey) private var customInstructions = ""
    @State private var customInstructionsDraft = ""
    @State private var hasLoadedCustomInstructionsDraft = false
    @State private var feedbackTrigger = 0

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default response tone")
                            .appFont(.headline, weight: .semibold)
                        Text(personality.explanation)
                            .appFont(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Menu {
                        Picker("Personality", selection: $personality) {
                            ForEach(PersonalityMode.allCases) { mode in
                                VStack(alignment: .leading) {
                                    Text(mode.displayName)
                                    Text(mode.explanation)
                                }
                                .tag(mode)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(personality.displayName)
                            Image(systemName: "chevron.up.chevron.down")
                                .appFont(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(AccessibilityID.personalityPicker)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.appElevated)

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sent with every message to every agent.")
                        .appFont(.subheadline)
                        .foregroundStyle(.secondary)

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
                    .frame(minHeight: 220)
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
                Text("Custom instructions")
                    .appFont(.headline)
                    .textCase(nil)
            }
            .listRowBackground(Color.appElevated)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedCanvas)
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .onAppear {
            guard !hasLoadedCustomInstructionsDraft else { return }
            customInstructionsDraft = customInstructions
            hasLoadedCustomInstructionsDraft = true
        }
    }

    private var normalizedCustomInstructionsDraft: String {
        CustomInstructions.normalized(customInstructionsDraft)
    }

    private var hasCustomInstructionsChanges: Bool {
        normalizedCustomInstructionsDraft != customInstructions
    }

    private func saveCustomInstructions() {
        customInstructions = normalizedCustomInstructionsDraft
        customInstructionsDraft = customInstructions
        feedbackTrigger += 1
    }
}

private struct PreferencePickerRow<Value: Hashable & Identifiable>: View {
    var title: String
    @Binding var selection: Value
    var options: [Value]
    var label: (Value) -> String

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
            Spacer(minLength: 8)
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 3)
    }
}

private struct FontSizeRow: View {
    var title: String
    @Binding var value: Double
    var defaultValue: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            TextField(
                title,
                value: $value,
                format: .number.precision(.fractionLength(0 ... 1))
            )
            .keyboardType(.decimalPad)
            .submitLabel(.done)
            .multilineTextAlignment(.trailing)
            .frame(width: 56)
            .accessibilityValue("\(value.formatted()) points")

            Text("pt")
                .foregroundStyle(.secondary)

            VStack(spacing: 2) {
                Button {
                    value = min(value.rounded(.down) + 1, FontSizePreference.allowedRange.upperBound)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(value >= FontSizePreference.allowedRange.upperBound)
                .accessibilityLabel("Increase \(title)")

                Button {
                    value = max(value.rounded(.up) - 1, FontSizePreference.allowedRange.lowerBound)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 28, height: 20)
                }
                .buttonStyle(.plain)
                .disabled(value <= FontSizePreference.allowedRange.lowerBound)
                .accessibilityLabel("Decrease \(title)")
            }
            .appFont(.caption2, weight: .semibold)
        }
        .padding(.vertical, 3)
        .onChange(of: value) { _, newValue in
            let normalized = min(
                max(newValue.isFinite ? newValue : defaultValue,
                    FontSizePreference.allowedRange.lowerBound),
                FontSizePreference.allowedRange.upperBound
            )
            if normalized != newValue {
                value = normalized
            }
        }
    }
}

private struct AgentSettingsRow: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?

    var body: some View {
        HStack(spacing: 12) {
            AgentAvatar(
                title: agent.displayName(info: info),
                connectionPhase: AgentConnectionPhase(info: info)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(agent.displayName(info: info))
                    .brandSerifFont(.body, weight: .semibold)
                    .lineLimit(1)
                Text(endpointText)
                    .appFont(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            AgentStatusLabel(
                connectionPhase: AgentConnectionPhase(info: info),
                showsActivityIndicator: false
            )
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
                .appFont(.callout)
            Spacer(minLength: 12)
            Text(value)
                .appFont(.footnote)
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
