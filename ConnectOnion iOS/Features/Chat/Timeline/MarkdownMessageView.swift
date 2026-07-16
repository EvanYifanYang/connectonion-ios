import SwiftUI

/// Renders an assistant message as block-level Markdown — headings, bullet/ordered lists, fenced code
/// blocks, blockquotes, tables, and horizontal rules — with inline formatting (bold, italic, code,
/// links) inside each block. `Text(LocalizedStringKey:)` only handles inline syntax, so anything with
/// a list, table, or code block used to render as one flat run; this walks the blocks instead.
struct MarkdownMessageView: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(MarkdownParser.parse(text).enumerated()), id: \.offset) { item in
                view(for: item.element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Agent replies read in the brand serif (New York) for an editorial feel; the code block sets
        // its own monospaced font, so code stays mono.
        .fontDesign(.serif)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            MarkdownInlineText(text)
                .font(headingFont(level))
                .fontWeight(.semibold)

        case .paragraph(let text):
            MarkdownInlineText(text)
                .lineSpacing(3)

        case .bulletList(let items):
            listView(items.map { (marker: "•", text: $0) })

        case .orderedList(let start, let items):
            listView(items.enumerated().map { (marker: "\(start + $0.offset).", text: $0.element) })

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code)

        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.onion.opacity(0.6))
                    .frame(width: 3)
                MarkdownInlineText(text)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .table(let header, let rows):
            MarkdownTableView(header: header, rows: rows)

        case .rule:
            Divider()
        }
    }

    private func listView(_ items: [(marker: String, text: String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.marker)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    MarkdownInlineText(item.text)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(.title2, design: .serif)
        case 2: .system(.title3, design: .serif)
        case 3: .system(.headline, design: .serif)
        default: .system(.body, design: .serif).weight(.semibold)
        }
    }
}

/// A `Text` that interprets inline Markdown (bold, italic, `code`, links) while leaving block syntax
/// untouched.
private struct MarkdownInlineText: View {
    private let attributed: AttributedString

    init(_ raw: String) {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        attributed = (try? AttributedString(markdown: raw, options: options)) ?? AttributedString(raw)
    }

    var body: some View {
        Text(attributed)
            .textSelection(.enabled)
            .tint(.onion)
    }
}

private struct CodeBlockView: View {
    var language: String?
    var code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }
}

private struct MarkdownTableView: View {
    var header: [String]
    var rows: [[String]]

    private var columnCount: Int {
        max(header.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { column in
                        cell(header, column).fontWeight(.semibold)
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { column in
                            cell(row, column)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private func cell(_ values: [String], _ column: Int) -> some View {
        Group {
            if column < values.count {
                MarkdownInlineText(values[column])
            } else {
                Text("")
            }
        }
        .gridColumnAlignment(.leading)
    }
}
