import SwiftUI
import UIKit

struct AgentBubble: View {
    var item: ChatItem
    var showActions: Bool = false
    var modelName: String? = nil
    var onRegenerate: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !item.content.isEmpty {
                MarkdownMessageView(text: item.content)
                    .equatable()
                    .font(.body)
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
