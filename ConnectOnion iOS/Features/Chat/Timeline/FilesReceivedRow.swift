import SwiftUI

struct FilesReceivedRow: View {
    var item: ChatItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Files received", systemImage: "tray.and.arrow.down")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(item.receivedFiles) { file in
                Text(file.name)
                    .font(.footnote.monospaced())
                    .lineLimit(1)
            }
        }
        .padding(12)
        .glassSurface(cornerRadius: 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 42)
        .padding(.vertical, 4)
    }
}

#Preview("Files Received") {
    FilesReceivedRow(item: PreviewFixtures.sampleFilesReceived)
        .padding()
}
