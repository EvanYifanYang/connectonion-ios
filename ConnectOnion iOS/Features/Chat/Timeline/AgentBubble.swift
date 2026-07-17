import SwiftUI
import UIKit

struct AgentBubble: View {
    var item: ChatItem
    var showActions: Bool = false
    var isStreaming: Bool = false
    var modelName: String? = nil
    var onRegenerate: () -> Void = {}
    var onStreamComplete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !item.content.isEmpty {
                if isStreaming {
                    StreamingMessageText(text: item.content, onComplete: onStreamComplete)
                } else {
                    MarkdownMessageView(text: item.content)
                        .font(.body)
                }
            }

            ForEach(item.images, id: \.self) { image in
                if let url = URL(string: image) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            ContentUnavailableView("Image unavailable", systemImage: "photo")
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxHeight: 360)
                    .clipShape(.rect(cornerRadius: 18))
                }
            }

            if showActions, !item.content.isEmpty {
                MessageActionsRow(content: item.content, onRegenerate: onRegenerate)
                    .padding(.top, 2)

                if let modelName {
                    HStack(spacing: 6) {
                        OnionThinkingMark(active: false, diameter: 16)
                        Text(modelName)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

/// Types the reply out client-side (the transport delivers it whole): reveals a growing prefix in the
/// brand serif with inline Markdown, trailed by an onion caret, then hands off to the full block-level
/// renderer once complete.
private struct StreamingMessageText: View {
    let text: String
    var onComplete: () -> Void

    @State private var revealed = 0
    // The inline markdown parsed ONCE (bold / italic / code / links). Revealing a growing prefix of the
    // already-formatted text keeps its layout stable — re-parsing a partial prefix every tick (the old
    // `Text(.init(prefix))`) reflowed the instant a token like `**` closed, and that reflow is the
    // flicker. Block syntax (lists, code fences) is left for the final MarkdownMessageView.
    @State private var attributed = AttributedString()

    var body: some View {
        let count = attributed.characters.count
        let end = attributed.index(attributed.startIndex, offsetByCharacters: min(revealed, count))
        let shown = AttributedString(attributed[attributed.startIndex..<end])

        let revealedText = Text(shown)
        let caretText = caret(visible: revealed < count)
        return Text("\(revealedText)\(caretText)")
            .font(.body)
            .fontDesign(.serif)
            .lineSpacing(3)
            .tint(.onion)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) { await reveal() }
    }

    private func caret(visible: Bool) -> Text {
        visible ? Text("▌").foregroundColor(.onion) : Text("")
    }

    private func reveal() async {
        attributed = (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
        revealed = 0
        let total = attributed.characters.count
        guard total > 0 else { onComplete(); return }
        // Reveal ~1 character per tick so short replies visibly type out; speed up (more per tick) only
        // for long replies so the whole thing still finishes within ~2.5s.
        let tickMs = 22
        let maxTicks = 2500.0 / Double(tickMs)
        let perTick = max(1, Int((Double(total) / maxTicks).rounded(.up)))
        while revealed < total {
            try? await Task.sleep(for: .milliseconds(tickMs))
            if Task.isCancelled { return }
            revealed = min(total, revealed + perTick)
        }
        onComplete()
    }
}

/// The small Copy / Regenerate / Share row under the latest assistant reply (Claude-style).
private struct MessageActionsRow: View {
    var content: String
    var onRegenerate: () -> Void

    @State private var copied = false

    var body: some View {
        HStack(spacing: 20) {
            Button {
                UIPasteboard.general.string = content
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
            }
            .accessibilityLabel(copied ? "Copied" : "Copy")

            Button(action: onRegenerate) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Regenerate")

            ShareLink(item: content) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share")
        }
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: copied) { _, isCopied in isCopied }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }
}

#Preview("Agent Bubble") {
    AgentBubble(item: PreviewFixtures.sampleAgentMessage, showActions: true)
        .padding()
}
