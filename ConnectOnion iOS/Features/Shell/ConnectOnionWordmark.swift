//
//  ConnectOnionWordmark.swift
//
//  Purpose: Implements ConnectOnionWordmark for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConversationSidebarRow, EmptyStateHero.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

/// The top-bar brand wordmark: "Connect" + the onion logo standing in for the capital O + "nion".
struct ConnectOnionWordmark: View {
    var logoSize: CGFloat = 27

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Connect")
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .padding(.horizontal, 1)
            Text("nion")
        }
        // A touch larger than the other nav titles so the brand reads at the top of the agent list.
        .connectOnionBrandFont(.title2, weight: .semibold)
        .lineLimit(1)
        .accessibilityLabel("ConnectOnion")
    }
}

#Preview("Wordmark") {
    ConnectOnionWordmark()
        .padding()
}
