import SwiftUI

struct AgentBubble: View {
    var item: ChatItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("O")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.primary, in: .rect(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 10) {
                if !item.content.isEmpty {
                    Text(.init(item.content))
                        .font(.body)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .contentTransition(.opacity)
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
            .frame(maxWidth: 650, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

#Preview("Agent Bubble") {
    AgentBubble(item: PreviewFixtures.sampleAgentMessage)
        .padding()
}
