import SwiftUI

struct ThinkingRow: View {
    var item: ChatItem

    var body: some View {
        HStack(spacing: 10) {
            OnionThinkingMark(active: item.status == .running)

            Text(text)
                .font(.footnote.monospaced())
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

        let model = item.model ?? "thinking"
        if item.status == .done {
            let tokens = item.usage?.totalTokens.map { " · \($0) tok" } ?? ""
            return "\(model)\(tokens)"
        }

        return model
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
