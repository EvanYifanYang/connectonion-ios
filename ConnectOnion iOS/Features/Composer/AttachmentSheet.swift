import Photos
import SwiftUI
import UIKit

/// The "Add to Chat" bottom sheet opened by the composer's + button. Mirrors Claude's layout: a row of
/// square tiles (Camera first, then recent library photos you tap to attach) with an "All photos"
/// shortcut to the full picker in the header, and a single "Add files" row below. (No projects / tools /
/// research / web-search rows — ConnectOnion doesn't have those.)
struct AttachmentSheet: View {
    var allowsImages: Bool
    var allowsFiles: Bool
    var onCamera: () -> Void
    var onAllPhotos: () -> Void
    var onPhotoData: (Data) -> Void
    var onPhotoError: (String) -> Void
    var onFiles: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recentPhotos = RecentPhotos()
    @State private var isSelecting = false
    @State private var loadTask: Task<Void, Never>?

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
            .overlay {
                if isSelecting {
                    ProgressView()
                        .padding(20)
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                        .allowsHitTesting(false) // keep Close tappable so a slow iCloud fetch can be cancelled
                }
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
            .onDisappear { loadTask?.cancel() }
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .task {
            if allowsImages { recentPhotos.load() }
        }
    }

    private var photoRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                if cameraAvailable {
                    cameraTile
                }
                if recentPhotos.isDenied {
                    enablePhotosTile
                }
                ForEach(recentPhotos.assets, id: \.localIdentifier) { asset in
                    PhotoThumbnailTile(asset: asset, provider: recentPhotos, side: tileSide) {
                        selectPhoto(asset)
                    }
                    .disabled(isSelecting)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: tileSide)
    }

    private var cameraTile: some View {
        Button {
            dismiss()
            onCamera()
        } label: {
            tileLabel(icon: "camera", title: "Camera")
        }
        .buttonStyle(.plain)
    }

    private var enablePhotosTile: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            tileLabel(icon: "lock.fill", title: "Enable Access")
        }
        .buttonStyle(.plain)
    }

    private func tileLabel(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.primary)
        .frame(width: tileSide, height: tileSide)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
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
        guard !isSelecting else { return } // first tap wins; ignore rapid repeats
        isSelecting = true
        loadTask = Task {
            let data = await recentPhotos.fullData(for: asset)
            guard !Task.isCancelled else { return } // sheet was dismissed mid-load — don't attach
            if let data {
                onPhotoData(data)
            } else {
                onPhotoError("Couldn’t attach that photo. Check your connection and try again.")
            }
            dismiss()
        }
    }
}

/// One square photo tile. Loads its own thumbnail so the row keeps the newest-first order and only
/// fetches what scrolls into view (the row is a LazyHStack). Shows a spinner while loading and a glyph
/// placeholder if the thumbnail can't be produced, instead of a blank square.
private struct PhotoThumbnailTile: View {
    let asset: PHAsset
    let provider: RecentPhotos
    let side: CGFloat
    var onTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        Button(action: onTap) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.secondarySystemBackground)
                        if didLoad {
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        } else {
                            ProgressView()
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .task(id: asset.localIdentifier) {
            image = await provider.thumbnail(for: asset, pixelSide: side * displayScale)
            didLoad = true
        }
    }
}
