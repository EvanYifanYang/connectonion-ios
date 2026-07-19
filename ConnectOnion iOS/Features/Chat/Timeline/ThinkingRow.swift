import SwiftUI

struct ThinkingRow: View {
    var item: ChatItem

    var body: some View {
        HStack(spacing: 10) {
            OnionThinkingMark(active: item.status == .running)

            Text(text)
                .appFont(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.leading, 18)
        .padding(.vertical, 4)
    }

    private var text: String {
        if let content = item.content.nilIfEmpty {
            return content
        }

        // Per-step rows show a neutral label, never the model name — the model is attributed once
        // per turn in the bottom AgentBubble footer, so repeating it here read as clutter.
        var details = [item.status == .running ? "Working" : "Thinking"]
        if item.status == .done {
            if let totalTokens = item.usage?.totalTokens {
                details.append("\(totalTokens) tok")
            }
        }

        return details.joined(separator: " · ")
    }
}

#Preview("Thinking Running") {
    ThinkingRow(item: PreviewFixtures.sampleThinking)
        .padding()
}

#Preview("Thinking Done") {
    ThinkingRow(item: PreviewFixtures.sampleThinkingDone)
        .padding()
}
