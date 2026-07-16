import SwiftUI
import SwiftData
import UIKit

struct AgentLandingView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var onSend: (AgentInput) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // A warm, serif greeting instead of repeating the agent hero.
            VStack(spacing: 10) {
                Text(greeting)
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
                Text("What shall we think through?")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date.now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
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
