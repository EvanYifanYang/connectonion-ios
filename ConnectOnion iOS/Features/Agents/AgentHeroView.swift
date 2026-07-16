import SwiftUI

struct AgentHeroView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?

    var body: some View {
        VStack(spacing: 12) {
            // No status dot on the avatar — the single "Connected" line below is the one status source.
            AgentAvatar(title: displayName, online: nil)
                .scaleEffect(1.2)
                .padding(.bottom, 8)

            Text(displayName)
                .font(AppFont.title)
                .lineLimit(1)

            if let online = info?.online {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(online ? Color.green : Color.secondary)
                        .symbolEffect(.pulse, options: .repeating, isActive: online) // gentle breathing while connected
                    Text(online ? "Connected" : "Offline")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(online ? Color.green : Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(online ? "Connected" : "Offline")
            }

            if let remoteProfileName {
                AgentProfileNameLabel(name: remoteProfileName)
            }

            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(AgentAddress(rawValue: agent.address)?.shortDisplay ?? agent.address)
                .font(.footnote.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    private var displayName: String {
        agent.displayName(info: info)
    }

    private var remoteProfileName: String? {
        agent.remoteProfileName(info: info)
    }

    private var metaLine: String {
        [
            info?.model,
            info?.trust,
            info?.version.map { "v\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

#Preview("Agent Hero") {
    AgentHeroView(agent: PreviewFixtures.sampleAgent, info: PreviewFixtures.sampleAgentInfo)
        .padding()
}

#Preview("Agent Hero Offline") {
    let agent = PreviewFixtures.sampleAgent
    let info = AgentInfo(address: PreviewFixtures.testAgentAddress, name: "OpenOnion", online: false)
    AgentHeroView(agent: agent, info: info)
        .padding()
}

#Preview("Agent Hero With Remote Profile") {
    let agent = AgentConfigRecord(address: PreviewFixtures.testAgentAddress, alias: "A1")
    let info = AgentInfo(
        address: PreviewFixtures.testAgentAddress,
        name: "OpenOnion",
        trust: "careful",
        version: "1.0",
        model: "co/gemini-2.5-flash",
        online: true
    )
    AgentHeroView(agent: agent, info: info)
        .padding()
}
