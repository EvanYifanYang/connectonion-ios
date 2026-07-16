import SwiftUI
import SwiftData
import UIKit

struct AgentLandingView: View {
    var agent: AgentConfigRecord
    var info: AgentInfo?
    var onSend: (AgentInput) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    AgentHeroView(agent: agent, info: info)

                    AgentCapabilityLine(info: info)
                }
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 58)
                .padding(.bottom, 28)
            }

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
        // The hero below already shows the agent's name prominently, so the top bar leaves its title
        // empty rather than repeating it.
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
