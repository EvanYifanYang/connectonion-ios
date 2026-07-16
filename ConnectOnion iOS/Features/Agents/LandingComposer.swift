import SwiftUI

struct LandingComposer: View {
    var acceptedInputs: AgentAcceptedInputs?
    var skills: [SkillInfo]
    var onSend: (String, [String], [FileAttachment]) -> Void

    var body: some View {
        ChatInputBar(
            placeholder: "Chat with ConnectOnion Agent",
            isRunning: false,
            acceptedInputs: acceptedInputs,
            skills: skills,
            onSend: onSend,
            onStop: {}
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color.appCanvas)
    }
}

#Preview("Landing Composer") {
    LandingComposer(
        acceptedInputs: PreviewFixtures.sampleAgentInfo.acceptedInputs,
        skills: PreviewFixtures.sampleSkills,
        onSend: { _, _, _ in }
    )
}
