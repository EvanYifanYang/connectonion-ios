import Foundation

enum CustomInstructions {
    static let storageKey = "customInstructions"

    private static let openingMarker = "<<<CONNECTONION_CUSTOM_INSTRUCTIONS_V1>>>"
    private static let closingMarker = "<<<CONNECTONION_END_CUSTOM_INSTRUCTIONS_V1>>>"
    private static let userRequestMarker = "<<<CONNECTONION_USER_REQUEST_V1>>>"

    @MainActor
    static var saved: String {
        normalized(UserDefaults.standard.string(forKey: storageKey) ?? "")
    }

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func injecting(_ instructions: String, into prompt: String) -> String {
        let instructions = normalized(instructions)
        guard !instructions.isEmpty else { return prompt }

        return """
        \(openingMarker)
        These are the user's saved preferences. Follow them unless they conflict with higher-priority instructions.

        \(instructions)
        \(closingMarker)

        \(userRequestMarker)
        \(prompt)
        """
    }

    static func removingWrapper(from prompt: String) -> String {
        guard prompt.hasPrefix(openingMarker) else { return prompt }

        let separator = "\n\(closingMarker)\n\n\(userRequestMarker)\n"
        guard let range = prompt.range(of: separator) else { return prompt }
        return String(prompt[range.upperBound...])
    }
}
