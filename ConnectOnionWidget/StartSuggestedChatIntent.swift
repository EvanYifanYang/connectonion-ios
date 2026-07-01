import AppIntents
import Foundation

struct StartSuggestedChatIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Chat"
    static let description = IntentDescription("Open ConnectOnion and start a suggested conversation.")
    static let openAppWhenRun = true

    @Parameter(title: "Agent")
    var agentAddress: String

    @Parameter(title: "Suggestion")
    var suggestion: String?

    init() {
        agentAddress = ""
        suggestion = nil
    }

    init(agentAddress: String, suggestion: String?) {
        self.agentAddress = agentAddress
        self.suggestion = suggestion
    }

    func perform() async throws -> some IntentResult {
        ConnectOnionPendingChatRequestStore.save(
            ConnectOnionPendingChatRequest(
                agentAddress: agentAddress.isEmpty ? nil : agentAddress,
                suggestion: suggestion
            )
        )
        return .result()
    }
}
