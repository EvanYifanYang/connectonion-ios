import SwiftUI
import SwiftData
import UIKit

struct AgentLandingView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var onSend: (AgentInput) -> Void

    private static let greetings = [
        "What shall we think through?",
        "How can I help you?",
        "Where should we start?",
        "What's on your mind?",
        "Ready when you are",
        "Good to see you"
    ]
    // Picked once per landing appearance so the greeting varies between new chats but stays put while
    // you're on the screen.
    @State private var greeting = AgentLandingView.greetings.randomElement() ?? "How can I help you?"

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // The brand logo over a single warm, serif greeting — no repeated agent hero. The onion
            // assembles itself layer-by-layer when the landing appears.
            VStack(spacing: 18) {
                OnionRevealView(trigger: greeting)
                    .frame(width: 60, height: 60)
                Text(greeting)
                    .appFont(.title, weight: .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            LandingComposer(
                acceptedInputs: info?.acceptedInputs,
                skills: info?.skills ?? [],
                onSend: { prompt, images, files in
                    onSend(AgentInput(prompt: prompt, images: images, files: files))
                }
            )
        }
        // Tapping the empty area (anywhere outside the composer's controls) dismisses the keyboard.
        .contentShape(.rect)
        .onTapGesture { dismissKeyboard() }
        .background(Color.appCanvas.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview("Agent Landing") {
    let _ = PreviewFixtures.installMockDependencies()
    let container = PreviewFixtures.seededContainer()
    if let agent = try? container.mainContext.fetch(FetchDescriptor<AgentConfigRecord>()).first {
        AgentLandingView(agent: agent, info: agent.cachedInfo) { _ in }
            .modelContainer(container)
    } else {
        Text("Preview unavailable")
    }
}

#Preview("Agent Landing Without Metadata") {
    let agent = AgentConfigRecord(address: PreviewFixtures.testAgentAddress, alias: "OpenOnion")
    AgentLandingView(agent: agent, info: nil) { _ in }
        .modelContainer(PreviewFixtures.container())
}
