import SwiftUI

struct AgentBubble: View {
    var item: ChatItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !item.content.isEmpty {
                MarkdownMessageView(text: item.content)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

#Preview("Agent Bubble") {
    AgentBubble(item: PreviewFixtures.sampleAgentMessage)
        .padding()
}
