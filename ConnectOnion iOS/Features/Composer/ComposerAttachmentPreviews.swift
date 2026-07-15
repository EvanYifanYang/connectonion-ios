import SwiftUI
import UIKit

struct ImageAttachmentDraft: Identifiable {
    let id: UUID
    var name: String
    var size: Int
    var dataURL: String
    var image: UIImage?

    init(id: UUID = UUID(), name: String, size: Int, dataURL: String, image: UIImage? = nil) {
        self.id = id
        self.name = name
        self.size = size
        self.dataURL = dataURL
        self.image = image
    }
}

struct ComposerAttachmentPreviewStrip: View {
    var images: [ImageAttachmentDraft]
    var files: [FileAttachment]
    var onRemoveImage: (UUID) -> Void
    var onRemoveFile: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(images) { image in
                    ImageAttachmentPreview(image: image, onRemove: onRemoveImage)
                }

                ForEach(files) { file in
                    FileAttachmentPreview(file: file, onRemove: onRemoveFile)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ImageAttachmentPreview: View {
    var image: ImageAttachmentDraft
    var onRemove: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = image.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 72, height: 72)
            .background(.quaternary)
            .clipShape(.rect(cornerRadius: 18))

            Button("Remove \(image.name)", systemImage: "xmark") {
                onRemove(image.id)
            }
            .labelStyle(.iconOnly)
            .font(.caption2.weight(.bold))
            .frame(width: 24, height: 24)
            .buttonStyle(.glass)
            .accessibilityIdentifier(AccessibilityID.attachmentRemove(image.id.uuidString))
            .offset(x: 6, y: -6)
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
    }
}

private struct FileAttachmentPreview: View {
    var file: FileAttachment
    var onRemove: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Text(formatFileSize(file.size))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button("Remove \(file.name)", systemImage: "xmark") {
                onRemove(file.id)
            }
            .labelStyle(.iconOnly)
            .font(.caption2.weight(.bold))
            .frame(width: 24, height: 24)
            .buttonStyle(.glass)
            .accessibilityIdentifier(AccessibilityID.attachmentRemove(file.id))
        }
        .padding(.leading, 11)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .glassSurface(cornerRadius: 16)
    }
}

/// File-size formatter shared by the composer (`ChatInputBar`) and `FileAttachmentPreview`.
func formatFileSize(_ bytes: Int) -> String {
    if bytes < 1024 {
        return "\(bytes) B"
    }

    if bytes < 1024 * 1024 {
        return String(format: "%.1f KB", Double(bytes) / 1024)
    }

    return String(format: "%.1f MB", Double(bytes) / Double(1024 * 1024))
}

#Preview("Attachment Preview Strip") {
    ComposerAttachmentPreviewStrip(
        images: [
            ImageAttachmentDraft(
                name: "Photo 1.png",
                size: 2400,
                dataURL: "data:image/png;base64,iVBORw0KGgo="
            )
        ],
        files: PreviewFixtures.sampleFiles,
        onRemoveImage: { _ in },
        onRemoveFile: { _ in }
    )
    .padding()
}
