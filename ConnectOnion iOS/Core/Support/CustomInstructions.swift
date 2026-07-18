import Foundation

enum CustomInstructions {
    static let storageKey = "customInstructions"

    private static let v1OpeningMarker = "<<<CONNECTONION_CUSTOM_INSTRUCTIONS_V1>>>"
    private static let v1ClosingMarker = "<<<CONNECTONION_END_CUSTOM_INSTRUCTIONS_V1>>>"
    private static let v1UserRequestMarker = "<<<CONNECTONION_USER_REQUEST_V1>>>"

    private static let v2OpeningMarker = "<<<CONNECTONION_PERSONALISATION_V2>>>"
    private static let v2ClosingMarker = "<<<CONNECTONION_END_PERSONALISATION_V2>>>"
    private static let v2UserRequestMarker = "<<<CONNECTONION_USER_REQUEST_V2>>>"

    @MainActor
    static var saved: String {
        normalized(UserDefaults.standard.string(forKey: storageKey) ?? "")
    }

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func injecting(_ instructions: String, into prompt: String) -> String {
        injecting(personality: .pragmatic, instructions: instructions, into: prompt)
    }

    static func injecting(
        personality: PersonalityMode,
        instructions: String,
        into prompt: String
    ) -> String {
        let instructions = normalized(instructions)
        let customInstructionsSection = instructions.isEmpty
            ? "No saved custom instructions."
            : instructions

        return """
        \(v2OpeningMarker)
        Apply the following saved personalisation unless it conflicts with higher-priority instructions.

        Selected personality:
        \(personality.promptInstruction)

        Custom instructions (these take precedence over the selected personality if they conflict):
        \(customInstructionsSection)
        \(v2ClosingMarker)

        \(v2UserRequestMarker)
        \(prompt)
        """
    }

    static func removingWrapper(from prompt: String) -> String {
        if prompt.hasPrefix(v2OpeningMarker) {
            return removingWrapper(
                from: prompt,
                closingMarker: v2ClosingMarker,
                userRequestMarker: v2UserRequestMarker
            )
        }
        if prompt.hasPrefix(v1OpeningMarker) {
            return removingWrapper(
                from: prompt,
                closingMarker: v1ClosingMarker,
                userRequestMarker: v1UserRequestMarker
            )
        }
        return prompt
    }

    private static func removingWrapper(
        from prompt: String,
        closingMarker: String,
        userRequestMarker: String
    ) -> String {
        let separator = "\n\(closingMarker)\n\n\(userRequestMarker)\n"
        guard let range = prompt.range(of: separator) else { return prompt }
        return String(prompt[range.upperBound...])
    }
}
