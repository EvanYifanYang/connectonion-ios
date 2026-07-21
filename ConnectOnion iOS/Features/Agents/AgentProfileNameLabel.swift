//
//  AgentProfileNameLabel.swift
//
//  Purpose: Implements AgentProfileNameLabel for the Features/Agents module.
//  Collaborates with: AgentCapabilityLine, AgentEditorView, AgentHeroView, AgentHomeView, AgentInfoPopover, AgentInfoStore.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import SwiftUI

struct AgentProfileNameLabel: View {
    var name: String
    var textStyle: Font.TextStyle = .footnote

    var body: some View {
        Label {
            Text("Profile: \(name)")
                .lineLimit(1)
        } icon: {
            Image(systemName: "person.text.rectangle")
                .imageScale(.small)
        }
        .appFont(textStyle)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Remote profile name \(name)")
    }
}

#Preview("Agent Profile Name") {
    AgentProfileNameLabel(name: "OpenOnion")
        .padding()
}
