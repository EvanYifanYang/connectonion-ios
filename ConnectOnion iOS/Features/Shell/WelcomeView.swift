import SwiftUI

struct WelcomeView: View {
    var onAddAgent: () -> Void

    @State private var feedbackTrigger = 0

    var body: some View {
        VStack(spacing: 18) {
            ConnectOnionLogoMark()

            Text("ConnectOnion")
                .font(.title.bold())

            Button("Add Agent", systemImage: "plus", action: addAgent)
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier(AccessibilityID.addAgentButton)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }

    private func addAgent() {
        feedbackTrigger += 1
        onAddAgent()
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
