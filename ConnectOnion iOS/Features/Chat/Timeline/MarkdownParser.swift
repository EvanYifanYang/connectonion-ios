//
//  MarkdownParser.swift
//
//  Purpose: Implements MarkdownParser for the Features/Chat/Timeline module.
//  Collaborates with: AgentActivityGroup, AgentBubble, ActivityStep, ActivityStepRow.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Foundation

/// One block-level element of a Markdown document.
enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([String])
    case orderedList(start: Int, [String])
    case codeBlock(language: String?, code: String)
    case quote(String)
    case table(header: [String], rows: [[String]])
    case rule
}

/// A small, dependency-free CommonMark-ish block parser — enough for assistant messages (headings,
/// lists, fenced code, blockquotes, GFM tables, rules). Inline syntax inside each block is left for
/// `AttributedString` to interpret at render time.
enum MarkdownParser {
    private static let cache = MarkdownBlockCache()

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let key = markdown as NSString
        if let cached = cache.storage.object(forKey: key) {
            return cached.blocks
        }

        let blocks = parseUncached(markdown)
        cache.storage.setObject(
            MarkdownBlockBox(blocks),
            forKey: key,
            cost: markdown.utf8.count
        )
        return blocks
    }

    private static func parseUncached(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Fenced code block.
            if let language = codeFence(trimmed) {
                var code: [String] = []
                i += 1
                while i < lines.count, codeFence(lines[i].trimmingCharacters(in: .whitespaces)) == nil {
                    code.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // closing fence
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: code.joined(separator: "\n")))
                continue
            }

            // Table: a `|` row immediately followed by a `---` separator row.
            if trimmed.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) {
                let header = tableCells(trimmed)
                var rows: [[String]] = []
                i += 2
                while i < lines.count {
                    let rowLine = lines[i].trimmingCharacters(in: .whitespaces)
                    guard !rowLine.isEmpty, rowLine.contains("|") else { break }
                    rows.append(tableCells(rowLine))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }

            // Horizontal rule.
            if isRule(trimmed) {
                blocks.append(.rule)
                i += 1
                continue
            }

            // Heading.
            if let heading = parseHeading(trimmed) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                i += 1
                continue
            }

            // Blockquote.
            if trimmed.hasPrefix(">") {
                var quote: [String] = []
                while i < lines.count {
                    let q = lines[i].trimmingCharacters(in: .whitespaces)
                    guard q.hasPrefix(">") else { break }
                    quote.append(String(q.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.quote(quote.joined(separator: "\n")))
                continue
            }

            // Lists.
            if let first = listItem(line) {
                var items: [String] = []
                while i < lines.count, let item = listItem(lines[i]), item.ordered == first.ordered {
                    items.append(item.text)
                    i += 1
                }
                blocks.append(first.ordered ? .orderedList(start: first.number ?? 1, items) : .bulletList(items))
                continue
            }

            // Paragraph — accumulate until a blank line or the start of another block.
            var paragraph: [String] = []
            while i < lines.count {
                let raw = lines[i]
                let t = raw.trimmingCharacters(in: .whitespaces)
                if t.isEmpty { break }
                if codeFence(t) != nil || isRule(t) || parseHeading(t) != nil || t.hasPrefix(">") || listItem(raw) != nil { break }
                if t.contains("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1].trimmingCharacters(in: .whitespaces)) { break }
                paragraph.append(t)
                i += 1
            }
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            }
        }

        return blocks
    }

    private static func codeFence(_ line: String) -> String? {
        if line.hasPrefix("```") { return String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
        if line.hasPrefix("~~~") { return String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
        return nil
    }

    private static func isRule(_ line: String) -> Bool {
        let s = line.replacingOccurrences(of: " ", with: "")
        guard s.count >= 3 else { return false }
        return s.allSatisfy { $0 == "-" } || s.allSatisfy { $0 == "*" } || s.allSatisfy { $0 == "_" }
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let level = line.prefix { $0 == "#" }.count
        guard level >= 1, level <= 6, line.count > level else { return nil }
        let rest = String(line.dropFirst(level))
        guard rest.hasPrefix(" ") else { return nil }
        // Strip an optional ATX closing-hash sequence (e.g. "## Notes ##").
        var text = rest.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") { text.removeLast() }
        return (level, text.trimmingCharacters(in: .whitespaces))
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.contains("-"), stripped.contains("|") else { return false }
        return stripped.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" }
    }

    private static func tableCells(_ line: String) -> [String] {
        var s = Substring(line)
        if s.hasPrefix("|") { s = s.dropFirst() }
        if s.hasSuffix("|") { s = s.dropLast() }
        return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func listItem(_ line: String) -> (ordered: Bool, number: Int?, text: String)? {
        let trimmed = line.drop { $0 == " " || $0 == "\t" }

        if let first = trimmed.first, first == "-" || first == "*" || first == "+" {
            let after = trimmed.dropFirst()
            if after.hasPrefix(" ") {
                return (false, nil, String(after).trimmingCharacters(in: .whitespaces))
            }
        }

        let digits = trimmed.prefix { $0.isNumber }
        if !digits.isEmpty {
            let after = trimmed.dropFirst(digits.count)
            if let marker = after.first, marker == "." || marker == ")" {
                let rest = after.dropFirst()
                if rest.hasPrefix(" ") {
                    return (true, Int(digits), String(rest).trimmingCharacters(in: .whitespaces))
                }
            }
        }

        return nil
    }
}

private final class MarkdownBlockBox {
    let blocks: [MarkdownBlock]

    init(_ blocks: [MarkdownBlock]) {
        self.blocks = blocks
    }
}

/// NSCache is internally synchronized. The wrapper makes that synchronization contract explicit to
/// Swift 6 while bounding retained documents for long-running chat sessions.
private final class MarkdownBlockCache: @unchecked Sendable {
    let storage = NSCache<NSString, MarkdownBlockBox>()

    init() {
        storage.countLimit = 80
        storage.totalCostLimit = 4 * 1_024 * 1_024
    }
}
