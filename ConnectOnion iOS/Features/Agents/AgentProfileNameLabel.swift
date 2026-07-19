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
