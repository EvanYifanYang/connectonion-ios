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
        Image("logo")
            .resizable()
            .scaledToFit()
            .frame(width: 52, height: 52)
            .frame(width: 76, height: 76)
            .glassSurface(cornerRadius: 24)
    }
}

#Preview("Welcome") {
    WelcomeView(onAddAgent: {})
}
