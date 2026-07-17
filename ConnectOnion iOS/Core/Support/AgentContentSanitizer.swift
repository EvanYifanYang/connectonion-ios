import Foundation

enum AgentContentSanitizer {
    private static let openingTokens = ["<system-reminder", "<system_reminder"]
    private static let closingTokens = ["</system-reminder", "</system_reminder"]

    static func sanitize(_ content: String) -> String {
        var result = content

        while let openingRange = earliestRange(of: openingTokens, in: result) {
            guard let openingEnd = result.range(
                of: ">",
                range: openingRange.lowerBound..<result.endIndex
            ) else {
                result.removeSubrange(openingRange.lowerBound..<result.endIndex)
                break
            }

            let remainder = openingEnd.upperBound..<result.endIndex
            guard let closingRange = earliestRange(of: closingTokens, in: result, range: remainder),
                  let closingEnd = result.range(of: ">", range: closingRange.lowerBound..<result.endIndex) else {
                // Treat an unterminated reminder as internal content through the end of the message.
                result.removeSubrange(openingRange.lowerBound..<result.endIndex)
                break
            }

            result.removeSubrange(openingRange.lowerBound..<closingEnd.upperBound)
        }

        // Remove orphaned closing tags without hiding the surrounding user-facing answer.
        while let closingRange = earliestRange(of: closingTokens, in: result) {
            guard let closingEnd = result.range(
                of: ">",
                range: closingRange.lowerBound..<result.endIndex
            ) else {
                result.removeSubrange(closingRange.lowerBound..<result.endIndex)
                break
            }
            result.removeSubrange(closingRange.lowerBound..<closingEnd.upperBound)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sanitize(_ item: ChatItem) -> ChatItem? {
        guard item.kind == .agent else { return item }

        var sanitized = item
        sanitized.content = sanitize(item.content)
        guard !sanitized.content.isEmpty || !sanitized.images.isEmpty || !sanitized.files.isEmpty else {
            return nil
        }
        return sanitized
    }

    static func sanitize(_ items: [ChatItem]) -> [ChatItem] {
        items.compactMap { sanitize($0) }
    }

    private static func earliestRange(
        of tokens: [String],
        in content: String,
        range: Range<String.Index>? = nil
    ) -> Range<String.Index>? {
        let searchRange = range ?? content.startIndex..<content.endIndex
        return tokens
            .compactMap { content.range(of: $0, options: .caseInsensitive, range: searchRange) }
            .min { $0.lowerBound < $1.lowerBound }
    }
}
