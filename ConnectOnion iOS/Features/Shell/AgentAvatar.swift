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

struct AgentAvatar: View {
    var title: String
    var online: Bool?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text(String(title.first ?? "O").uppercased())
                .appFont(.headline)
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 42, height: 42)
                .background(.primary, in: .rect(cornerRadius: 13))

            if let online {
                Circle()
                    .fill(online ? .green : .secondary)
                    .frame(width: 11, height: 11)
                    .overlay {
                        Circle().stroke(.background, lineWidth: 2)
                    }
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview("Agent Avatar Online") {
    AgentAvatar(title: "OpenOnion", online: true)
        .padding()
}

#Preview("Agent Avatar Offline") {
    AgentAvatar(title: "OpenOnion", online: false)
        .padding()
}
