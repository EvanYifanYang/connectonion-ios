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
            HStack(spacing: 10) {
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

/// The dark circular ✕ that sits in the top-right corner of every attachment card (Claude-style).
/// Adaptive: dark circle + light glyph in light mode, inverted in dark mode.
private struct AttachmentRemoveButton: View {
    var accessibilityLabel: String
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .appFont(.caption2, weight: .bold)
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 22, height: 22)
                .background(Color(.label), in: .circle)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                .frame(width: 36, height: 36) // enlarge the tap target; the visible circle stays 22pt
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }
}

private struct ImageAttachmentPreview: View {
    var image: ImageAttachmentDraft
    var onRemove: (UUID) -> Void

    private let side: CGFloat = 88

    var body: some View {
        Group {
            if let uiImage = image.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray6)
                    Image(systemName: "photo")
                        .appFont(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            AttachmentRemoveButton(
                accessibilityLabel: "Remove \(image.name)",
                identifier: AccessibilityID.attachmentRemove(image.id.uuidString)
            ) {
                onRemove(image.id)
            }
        }
    }
}

private struct FileAttachmentPreview: View {
    var file: FileAttachment
    var onRemove: (String) -> Void

    private let height: CGFloat = 88

    private var baseName: String {
        (file.name as NSString).deletingPathExtension
    }

    private var badge: String {
        let ext = (file.name as NSString).pathExtension
        return ext.isEmpty ? "FILE" : String(ext.uppercased().prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(badge)
                .appFont(.caption2, weight: .bold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.systemGray5), in: .rect(cornerRadius: 6))

            Spacer(minLength: 0)

            Text(baseName)
                .appFont(.subheadline, weight: .medium)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.primary)
        }
        .padding(10)
        .frame(width: 148, height: height, alignment: .leading)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            AttachmentRemoveButton(
                accessibilityLabel: "Remove \(file.name)",
                identifier: AccessibilityID.attachmentRemove(file.id)
            ) {
                onRemove(file.id)
            }
        }
    }
}

/// File-size formatter shared by the composer (`ChatInputBar`) and file previews.
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
