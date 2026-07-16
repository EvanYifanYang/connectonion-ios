import SwiftUI
import UIKit

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

    @State private var copied = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: language label + copy / expand actions (Claude-style).
            HStack(spacing: 16) {
                Text(language?.nilIfEmpty ?? "code")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    UIPasteboard.general.string = code
                    copied = true
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .accessibilityLabel(copied ? "Copied" : "Copy code")

                Button {
                    expanded = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("Expand code")
            }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCodeBlock, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .sensoryFeedback(.success, trigger: copied) { _, isCopied in isCopied }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
        .sheet(isPresented: $expanded) {
            CodeBlockExpandedView(language: language, code: code)
        }
    }
}

/// Full-screen reading view for a code block: scrolls both axes, selectable, with a Done button.
private struct CodeBlockExpandedView: View {
    var language: String?
    var code: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Text(code)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.appCanvas)
            .navigationTitle(language?.nilIfEmpty ?? "Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: code) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share code")
                }
            }
        }
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
            .padding(.vertical, 4)
        }
        // Tables render plain (dividers only, no card fill) — an editorial table, not a panel.
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
