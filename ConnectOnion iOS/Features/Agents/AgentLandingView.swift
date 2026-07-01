import SwiftUI
import SwiftData

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
                suggestions: AgentPromptSuggestions.defaults,
                acceptedInputs: info?.acceptedInputs,
                skills: info?.skills ?? [],
                onSend: { prompt, images, files in
                    onSend(AgentInput(prompt: prompt, images: images, files: files))
                }
            )
        }
        .navigationTitle(agent.displayName(info: info))
        .navigationBarTitleDisplayMode(.inline)
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
