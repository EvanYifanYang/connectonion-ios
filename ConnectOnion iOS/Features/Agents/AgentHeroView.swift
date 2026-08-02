//
//  AgentHeroView.swift
//
//  Purpose: Implements AgentHeroView for the Features/Agents module.
//  Collaborates with: AgentCapabilityLine, AgentEditorView, AgentHomeView, AgentInfoPopover, AgentInfoStore, AgentLandingView.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct AgentHeroView: View {
    @Environment(\.deviceIsOffline) private var deviceIsOffline

    var agent: AgentConfigRecord
    var info: AgentInfo?

    var body: some View {
        VStack(spacing: 12) {
            // No status dot on the avatar — the status line below is the one status source.
            AgentAvatar(title: displayName, connectionPhase: nil)
                .scaleEffect(1.2)
                .padding(.bottom, 8)

            Text(displayName)
                .appFont(.title2, weight: .semibold)
                .lineLimit(1)

            AgentStatusLabel(connectionPhase: AgentConnectionPhase(info: info).offlineAware(deviceIsOffline: deviceIsOffline))

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
