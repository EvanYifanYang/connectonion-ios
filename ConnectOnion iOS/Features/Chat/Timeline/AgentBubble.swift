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

    var body: some View {
        (Text(.init(String(text.prefix(revealed)))) + Text("▌").foregroundColor(.onion))
            .font(.body)
            .fontDesign(.serif)
            .lineSpacing(3)
            .tint(.onion)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) { await reveal() }
    }

    private func reveal() async {
        revealed = 0
        let total = text.count
        guard total > 0 else { onComplete(); return }
        let duration = min(2.0, Double(total) * 0.014)
        let perTick = max(1, Int((Double(total) / (duration * 60)).rounded(.up)))
        while revealed < total {
            try? await Task.sleep(for: .milliseconds(16))
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
        .sensoryFeedback(.success, trigger: copied)
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
