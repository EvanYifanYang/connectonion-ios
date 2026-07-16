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

            // A light identity only — the agent's home already showed the full hero, so don't repeat it.
            VStack(spacing: 10) {
                AgentAvatar(title: agent.displayName(info: info), online: nil)
                    .scaleEffect(1.1)
                Text("New chat with \(agent.displayName(info: info))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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
        .navigationTitle(agent.displayName(info: info))
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
