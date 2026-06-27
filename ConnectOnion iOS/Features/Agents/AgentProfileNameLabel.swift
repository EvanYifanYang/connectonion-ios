import SwiftUI

struct AgentProfileNameLabel: View {
    var name: String
    var font: Font = .footnote

    var body: some View {
        Label {
            Text("Profile: \(name)")
                .lineLimit(1)
        } icon: {
            Image(systemName: "person.text.rectangle")
                .imageScale(.small)
        }
        .font(font)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Remote profile name \(name)")
    }
}

#Preview("Agent Profile Name") {
    AgentProfileNameLabel(name: "OpenOnion")
        .padding()
}
