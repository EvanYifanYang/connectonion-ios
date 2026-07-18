import SwiftUI
import UIKit

struct AttachmentStrip: View {
    var images: [String] = []
    var files: [FileAttachment]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    DataURLImage(dataURL: image)
                        .frame(width: 88, height: 88)
                        .clipShape(.rect(cornerRadius: 18))
                        .glassSurface(cornerRadius: 18)
                }

                ForEach(files) { file in
                    Label(file.name, systemImage: "doc")
                        .appFont(.footnote)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .glassSurface(cornerRadius: 12)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: 620, alignment: .trailing)
    }
}

private struct DataURLImage: View {
    var dataURL: String

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .appFont(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.quaternary)
    }

    private var image: UIImage? {
        guard let data = AttachmentEncoding.decodedData(from: dataURL) else { return nil }
        return UIImage(data: data)
    }
}

#Preview("Attachment Strip") {
    AttachmentStrip(
        images: ["data:image/png;base64,iVBORw0KGgo="],
        files: PreviewFixtures.sampleFiles
    )
        .padding()
}
