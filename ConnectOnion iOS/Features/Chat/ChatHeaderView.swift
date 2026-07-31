//
//  ChatHeaderView.swift
//
//  Purpose: Implements ChatHeaderView for the Features/Chat module.
//  Collaborates with: ChatErrorBanner, ChatItemView, ChatMessageList, ChatScreen, ChatTimeline, ChatViewModel.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct ChatHeaderView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var state: SessionActiveState
    var elapsedTime: TimeInterval

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 12) {
                AgentAvatar(title: displayName, connectionPhase: connectionPhase)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .appFont(.headline)
                        .lineLimit(1)

                    Text(subtitleText)
                        .appFont(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .lineLimit(1)
                        .animation(AppMotion.quick, value: subtitleText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassSurface(cornerRadius: 24)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var statusText: String {
        switch state {
        case .connecting:
            "Connecting"
        case .active:
            "Working · \(elapsedTime.formattedDuration)"
        case .waiting:
            "Waiting"
        case .reconnecting:
            "Reconnecting"
        case .disconnected:
            "Disconnected"
        case .connected:
            "Connected"
        case .idle:
            if let online = info?.online {
                online ? "Online" : "Offline"
            } else {
                "Ready"
            }
        }
    }

    private var subtitleText: String {
        if let remoteProfileName {
            "\(statusText) · Profile: \(remoteProfileName)"
        } else {
            statusText
        }
    }

    private var displayName: String {
        agent.displayName(info: info)
    }

    private var remoteProfileName: String? {
        agent.remoteProfileName(info: info)
    }

    private var connectionPhase: AgentConnectionPhase {
        switch state {
        case .connected, .active, .waiting:
            .online
        case .disconnected:
            .offline
        case .idle, .connecting, .reconnecting:
            AgentConnectionPhase(info: info)
        }
    }
}

#Preview("Chat Header Ready") {
    ChatHeaderView(agent: PreviewFixtures.sampleAgent, info: PreviewFixtures.sampleAgentInfo, state: .idle, elapsedTime: 0)
}

#Preview("Chat Header Active") {
    ChatHeaderView(agent: PreviewFixtures.sampleAgent, info: PreviewFixtures.sampleAgentInfo, state: .active, elapsedTime: 12.4)
}

#Preview("Chat Header With Remote Profile") {
    let agent = AgentConfigRecord(address: PreviewFixtures.testAgentAddress, alias: "A1")
    let info = AgentInfo(address: PreviewFixtures.testAgentAddress, name: "OpenOnion", online: true)
    ChatHeaderView(agent: agent, info: info, state: .idle, elapsedTime: 0)
}
