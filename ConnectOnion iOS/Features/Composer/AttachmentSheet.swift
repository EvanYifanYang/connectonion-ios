import Photos
import SwiftUI
import UIKit

/// The "Add to Chat" bottom sheet opened by the composer's + button. Mirrors Claude's layout: a row of
/// square tiles (Camera first, then recent photos you can tap to attach) with an "All photos" shortcut
/// to the full library in the header, and a single "Add files" row below. (No projects / tools /
/// research / web-search rows — ConnectOnion doesn't have those.)
struct AttachmentSheet: View {
    var allowsImages: Bool
    var allowsFiles: Bool
    var onCamera: () -> Void
    var onAllPhotos: () -> Void
    var onPhotoData: (Data) -> Void
    var onFiles: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recentPhotos = RecentPhotos()

    private let tileSide: CGFloat = 96

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if allowsImages {
                        photoRow
                    }
                    if allowsFiles {
                        addFilesRow
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Add to Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                if allowsImages {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("All photos") {
                            dismiss()
                            onAllPhotos()
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .task {
            if allowsImages { recentPhotos.load() }
        }
    }

    private var photoRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if cameraAvailable {
                    cameraTile
                }
                ForEach(recentPhotos.assets, id: \.localIdentifier) { asset in
                    PhotoThumbnailTile(asset: asset, provider: recentPhotos, side: tileSide) {
                        selectPhoto(asset)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var cameraTile: some View {
        Button {
            dismiss()
            onCamera()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "camera")
                    .font(.title2)
                Text("Camera")
                    .font(.subheadline)
            }
            .foregroundStyle(.primary)
            .frame(width: tileSide, height: tileSide)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var addFilesRow: some View {
        Button {
            dismiss()
            onFiles()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc")
                    .font(.body)
                    .frame(width: 24)
                Text("Add files")
                    .font(.body)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var sheetHeight: CGFloat {
        var height: CGFloat = 60 // header
        if allowsImages { height += tileSide + 28 }
        if allowsFiles { height += 60 }
        return height + 24
    }

    private func selectPhoto(_ asset: PHAsset) {
        Task {
            let data = await recentPhotos.fullData(for: asset)
            if let data { onPhotoData(data) }
            dismiss()
        }
    }
}

/// One square photo tile. Loads its own thumbnail on appear so the row keeps the newest-first order and
/// only fetches what scrolls into view.
private struct PhotoThumbnailTile: View {
    let asset: PHAsset
    let provider: RecentPhotos
    let side: CGFloat
    var onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .task {
            if image == nil {
                image = await provider.thumbnail(for: asset, side: side)
            }
        }
    }
}
