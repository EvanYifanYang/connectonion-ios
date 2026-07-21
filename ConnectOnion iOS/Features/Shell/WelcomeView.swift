//
//  WelcomeView.swift
//
//  Purpose: Implements WelcomeView for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct WelcomeView: View {
    var onAddAgent: () -> Void

    var body: some View {
        EmptyStateHero(onAddAgent: onAddAgent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color.appCanvas)
    }
}

struct ConnectOnionLogoMark: View {
    var body: some View {
        OnionPeelLogoView()
            .frame(width: 62, height: 62)
            .frame(width: 76, height: 76)
            .glassSurface(cornerRadius: 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ConnectOnion logo")
    }
}

#Preview("Welcome") {
    WelcomeView(onAddAgent: {})
}
