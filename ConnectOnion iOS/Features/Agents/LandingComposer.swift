import SwiftUI

struct LandingComposer: View {
    var suggestions: [String]
    var acceptedInputs: AgentAcceptedInputs?
    var skills: [SkillInfo]
    var onSend: (String, [String], [FileAttachment]) -> Void

    var body: some View {
        VStack(spacing: 12) {
            PromptSuggestionStrip(suggestions: suggestions) { suggestion in
                onSend(suggestion, [], [])
            }

            ChatInputBar(
                placeholder: "Message this agent",
                isRunning: false,
                acceptedInputs: acceptedInputs,
                skills: skills,
                onSend: onSend,
                onStop: {}
            )
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.background)
    }
}

#Preview("Landing Composer") {
    LandingComposer(
        suggestions: ["What can you do?", "Show system info", "List files"],
        acceptedInputs: PreviewFixtures.sampleAgentInfo.acceptedInputs,
        skills: PreviewFixtures.sampleSkills,
        onSend: { _, _, _ in }
    )
}
