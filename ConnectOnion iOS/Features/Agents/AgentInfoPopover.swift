import SwiftUI

/// Compact popover of an agent's technical details, opened from the info button on its home. Mirrors
/// the Settings "About" popover: plain label / value rows with dividers, no chrome.
struct AgentInfoPopover: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.label) { index, row in
                if index > 0 { Divider() }
                infoRow(row.label, value: row.value)
            }
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

    private struct Row {
        let label: String
        let value: String
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
        result.append(Row(label: "Address", value: AgentAddress(rawValue: agent.address)?.shortDisplay ?? agent.address))
        return result
    }
}

#Preview("Agent Info Popover") {
    AgentInfoPopover(agent: PreviewFixtures.sampleAgent, info: PreviewFixtures.sampleAgentInfo)
}
