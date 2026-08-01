//
//  AgentAvatar.swift
//
//  Purpose: Implements AgentAvatar for the Features/Shell module.
//  Collaborates with: AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow, EmptyStateHero.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

enum AgentConnectionPhase: Equatable, Sendable {
    case checking
    case online
    case offline
    /// This iPhone has no network path at all — the agent's own state is unknown, so saying "Offline"
    /// would blame the wrong side.
    case noInternet

    init(info: AgentInfo?) {
        guard let info else {
            self = .checking
            return
        }
        self = info.online ? .online : .offline
    }

    var accessibilityLabel: String {
        switch self {
        case .checking:
            "Connecting"
        case .online:
            "Online"
        case .offline:
            "Offline"
        case .noInternet:
            "No internet"
        }
    }
}

struct AgentAvatar: View {
    var title: String
    /// Nil intentionally hides the badge (for surfaces that present a full status label nearby).
    var connectionPhase: AgentConnectionPhase?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(String(title.first ?? "O").uppercased())
                .appFont(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 42, height: 42)
                .background(.primary, in: .rect(cornerRadius: 13))

            if let connectionPhase {
                statusBadge(for: connectionPhase)
            }
        }
    }

    @ViewBuilder
    private func statusBadge(for phase: AgentConnectionPhase) -> some View {
        switch phase {
        case .checking:
            ProgressView()
                .controlSize(.mini)
                .tint(.secondary)
                .frame(width: 13, height: 13)
                .background(.background, in: .circle)
                .accessibilityHidden(true)
        case .online, .offline, .noInternet:
            Circle()
                .fill(phase == .online ? .green : .secondary)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle().stroke(.background, lineWidth: 2)
                }
                .accessibilityHidden(true)
        }
    }
}

struct AgentStatusLabel: View {
    var connectionPhase: AgentConnectionPhase
    var showsActivityIndicator = true

    var body: some View {
        HStack(spacing: 5) {
            switch connectionPhase {
            case .checking:
                if showsActivityIndicator {
                    ProgressView()
                        .controlSize(.mini)
                }
            case .online, .offline, .noInternet:
                Circle()
                    .fill(connectionPhase == .online ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
            }

            Text(label)
                .appFont(.footnote)
        }
        .foregroundStyle(foregroundStyle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(connectionPhase.accessibilityLabel)
    }

    private var label: String {
        switch connectionPhase {
        case .checking:
            "Connecting…"
        case .online:
            "Online"
        case .offline:
            "Offline"
        case .noInternet:
            "No internet"
        }
    }

    private var foregroundStyle: Color {
        switch connectionPhase {
        case .checking:
            Color.secondary
        case .online:
            Color.green
        case .offline, .noInternet:
            Color.secondary
        }
    }
}

#Preview("Agent Avatar Online") {
    AgentAvatar(title: "OpenOnion", connectionPhase: .online)
        .padding()
}

#Preview("Agent Avatar Offline") {
    AgentAvatar(title: "OpenOnion", connectionPhase: .offline)
        .padding()
}

#Preview("Agent Avatar Checking") {
    AgentAvatar(title: "OpenOnion", connectionPhase: .checking)
        .padding()
}
