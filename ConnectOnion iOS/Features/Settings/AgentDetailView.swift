import SwiftUI

/// Edit one added agent from Settings: its display name, its direct endpoint (the LAN address a
/// phone needs to reach a local agent), plus its address, live status, and a delete action.
struct AgentDetailView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var endpoint: String
    @State private var confirmingDelete = false
    @State private var feedbackTrigger = 0

    init(agent: AgentConfigRecord, info: AgentInfo?, onDelete: @escaping () -> Void) {
        self.agent = agent
        self.info = info
        self.onDelete = onDelete
        _name = State(initialValue: agent.alias)
        _endpoint = State(initialValue: agent.preferredEndpoint?.absoluteString ?? "")
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    AgentAvatar(title: agent.displayName(info: info), online: info?.online)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(agent.displayName(info: info))
                            .font(AppFont.sectionSerif)
                            .lineLimit(1)
                        AgentStatusLabel(online: info?.online)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.appElevated)

            Section {
                TextField("Name", text: $name)
                    .tint(.primary)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Name").font(AppFont.sectionSerif).textCase(nil)
            }
            .listRowBackground(Color.appElevated)

            Section {
                TextField("http://192.168.0.10:8000", text: $endpoint)
                    .font(.body.monospaced())
                    .tint(.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } header: {
                Text("Endpoint").font(AppFont.sectionSerif).textCase(nil)
            } footer: {
                Text("The agent's LAN address, so this phone can reach it on the same Wi‑Fi.")
            }
            .listRowBackground(Color.appElevated)

            Section {
                Text(agent.address)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text("Address").font(AppFont.sectionSerif).textCase(nil)
            }
            .listRowBackground(Color.appElevated)

            Section {
                Button {
                    confirmingDelete = true
                } label: {
                    // Plain style + explicit red so the trash icon is red too (a Form button otherwise
                    // tints the icon with the accent purple).
                    Label("Delete Agent", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.deleteAgentButton)
            }
            .listRowBackground(Color.appElevated)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedCanvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Agent").font(AppFont.wordmark)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
                    .accessibilityIdentifier(AccessibilityID.saveAgentButton)
            }
        }
        .confirmationDialog("Delete Agent?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Agent", role: .destructive) {
                // Pop first, then delete, so this view isn't reading an invalidated model mid-teardown.
                dismiss()
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private var canSave: Bool {
        AgentEndpoint.normalized(from: endpoint) != nil
    }

    private func save() {
        guard case .some(let url) = AgentEndpoint.normalized(from: endpoint) else { return }
        agent.alias = name.trimmingCharacters(in: .whitespacesAndNewlines)
        agent.preferredEndpoint = url
        agent.updatedAt = .now
        feedbackTrigger += 1
        dismiss()
    }
}

/// Small "● Online / Offline" status line reused across agent surfaces.
struct AgentStatusLabel: View {
    var online: Bool?

    var body: some View {
        if let online {
            HStack(spacing: 5) {
                Circle()
                    .fill(online ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(online ? "Online" : "Offline")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Checking…")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}
