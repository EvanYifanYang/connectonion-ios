//
//  SidebarSectionTitle.swift
//
//  Purpose: Implements SidebarSectionTitle for the Features/Shell module.
//  Collaborates with: AgentAvatar, AgentListView, AgentSidebarRow, AppShellView, ConnectOnionWordmark, ConversationSidebarRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct SidebarSectionTitle: View {
    var title: String

    var body: some View {
        Text(title)
            .brandSerifFont(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }
}

#Preview("Sidebar Section Title") {
    SidebarSectionTitle(title: "Agents")
        .padding()
}
