import SwiftUI

struct ChatHeaderView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var state: SessionActiveState
    var elapsedTime: TimeInterval

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 12) {
                AgentAvatar(title: displayName, online: isOnline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .animation(AppMotion.quick, value: statusText)
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
            info?.online == false ? "Offline" : "Connected"
        case .idle:
            if let online = info?.online {
                online ? "Online" : "Offline"
            } else {
                "Ready"
            }
        }
    }

    private var displayName: String {
        info?.name ?? agent.displayName
    }

    private var isOnline: Bool {
        switch state {
        case .active, .waiting:
            true
        case .disconnected:
            false
        case .connected, .idle, .connecting, .reconnecting:
            info?.online ?? false
        }
    }
}

#Preview("Chat Header Ready") {
    ChatHeaderView(agent: PreviewFixtures.sampleAgent, info: PreviewFixtures.sampleAgentInfo, state: .idle, elapsedTime: 0)
}

#Preview("Chat Header Active") {
    ChatHeaderView(agent: PreviewFixtures.sampleAgent, info: PreviewFixtures.sampleAgentInfo, state: .active, elapsedTime: 12.4)
}
