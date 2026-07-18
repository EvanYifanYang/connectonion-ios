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
                .appFont(.title2, weight: .semibold)
                .lineLimit(1)

            if let online = info?.online {
                HStack(spacing: 6) {
                    Circle()
                        .fill(online ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(online ? "Connected" : "Offline")
                        .appFont(.footnote, weight: .medium)
                        .foregroundStyle(online ? Color.green : Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(online ? "Connected" : "Offline")
            }

            if !metaLine.isEmpty {
                Text(metaLine)
                    .appFont(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var displayName: String {
        agent.displayName(info: info)
    }

    // Slim hero: just model · trust. Profile, version and the full address live in the info sheet.
    private var metaLine: String {
        [info?.model, info?.trust]
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
