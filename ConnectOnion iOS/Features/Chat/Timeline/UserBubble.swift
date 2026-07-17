import SwiftUI

struct UserBubble: View {
    var item: ChatItem

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !item.images.isEmpty || !item.files.isEmpty {
                AttachmentStrip(images: item.images, files: item.files)
            }

            if !item.content.isEmpty {
                Text(.init(item.content))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appUserBubble, in: .rect(cornerRadius: AppTheme.bubbleCornerRadius))
                    .frame(maxWidth: 620, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.vertical, 5)
    }
}

#Preview("User Bubble") {
    UserBubble(item: PreviewFixtures.sampleUserMessage)
        .padding()
}
