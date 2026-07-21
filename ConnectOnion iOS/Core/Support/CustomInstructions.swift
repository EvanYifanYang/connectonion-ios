//
//  CustomInstructions.swift
//
//  Purpose: Implements CustomInstructions for the Core/Support module.
//  Collaborates with: AccessibilityID, AgentContentSanitizer, AttachmentEncoding, HexCoding, JSONValue, PersonalisationPreferences.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

enum CustomInstructions {
    static let storageKey = "customInstructions"

    private static let v1OpeningMarker = "<<<CONNECTONION_CUSTOM_INSTRUCTIONS_V1>>>"
    private static let v1ClosingMarker = "<<<CONNECTONION_END_CUSTOM_INSTRUCTIONS_V1>>>"
    private static let v1UserRequestMarker = "<<<CONNECTONION_USER_REQUEST_V1>>>"

    private static let v2OpeningMarker = "<<<CONNECTONION_PERSONALISATION_V2>>>"
    private static let v2ClosingMarker = "<<<CONNECTONION_END_PERSONALISATION_V2>>>"
    private static let v2UserRequestMarker = "<<<CONNECTONION_USER_REQUEST_V2>>>"

    private static let systemReminderOpeningMarker = "<system-reminder>"
    private static let systemReminderClosingMarker = "</system-reminder>"

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

    /// Removes transport-only context that an agent host may echo back in canonical user messages.
    /// Complete leading reminder envelopes are stripped; malformed or inline tags are left untouched.
    static func visiblePrompt(from prompt: String) -> String {
        var visible = prompt
        while true {
            let previous = visible
            visible = removingLeadingSystemReminder(from: visible)
            visible = removingWrapper(from: visible)
            guard visible != previous else { return visible }
        }
    }

    private static func removingLeadingSystemReminder(from prompt: String) -> String {
        let start = prompt.firstIndex { !$0.isWhitespace } ?? prompt.endIndex
        let candidate = prompt[start...]
        guard candidate.hasPrefix(systemReminderOpeningMarker),
              let closingRange = candidate.range(of: systemReminderClosingMarker) else {
            return prompt
        }

        let remainder = candidate[closingRange.upperBound...]
        let visibleStart = remainder.firstIndex { !$0.isWhitespace } ?? remainder.endIndex
        return String(remainder[visibleStart...])
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
