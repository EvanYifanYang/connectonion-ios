import SwiftUI

/// Read-only details for one agent, shown from the info button on its home. Holds the technical
/// metadata kept off the slim hero: remote profile, trust, version, and the full address.
struct AgentInfoSheet: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        AgentAvatar(title: displayName, online: info?.online)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName)
                                .font(AppFont.sectionSerif)
                                .lineLimit(1)
                            AgentStatusLabel(online: info?.online)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(rows, id: \.label) { row in
                        LabeledContent(row.label) {
                            Text(row.value)
                                .font(row.mono ? .callout.monospaced() : .body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("Details").font(AppFont.sectionSerif).textCase(nil)
                }
            }
            .navigationTitle("Agent Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var displayName: String { agent.displayName(info: info) }

    private struct Row {
        let label: String
        let value: String
        var mono: Bool = false
    }

    private var rows: [Row] {
        var result: [Row] = []
        if let profile = agent.remoteProfileName(info: info) {
            result.append(Row(label: "Profile", value: profile))
        }
        if let model = info?.model, !model.isEmpty {
            result.append(Row(label: "Model", value: model))
        }
        if let trust = info?.trust, !trust.isEmpty {
            result.append(Row(label: "Trust", value: trust))
        }
        if let version = info?.version, !version.isEmpty {
            result.append(Row(label: "Version", value: "v\(version)"))
        }
        result.append(Row(label: "Address", value: agent.address, mono: true))
        return result
    }
}

#Preview("Agent Info") {
    AgentInfoSheet(agent: PreviewFixtures.sampleAgent, info: PreviewFixtures.sampleAgentInfo)
}
