import Photos
import SwiftUI
import UIKit

/// The "Add to Chat" bottom sheet opened by the composer's + button. Mirrors Claude's layout: a row of
/// square tiles (Camera first, then recent library photos you can multi-select) with an "All photos"
/// shortcut in the header and a single "Add files" row below. Selecting photos reveals an
/// "Attach N photos" button. (No projects / tools / research / web-search rows — we don't have those.)
struct AttachmentSheet: View {
    var allowsImages: Bool
    var allowsFiles: Bool
    var onCamera: () -> Void
    var onAllPhotos: () -> Void
    var onPhotosData: ([Data]) -> Void
    var onPhotoError: (String) -> Void
    var onFiles: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recentPhotos = RecentPhotos()
    @State private var selected: [String] = [] // asset identifiers, in tap order
    @State private var isAttaching = false
    @State private var loadTask: Task<Void, Never>?

    private let tileSide: CGFloat = 96
    private let tileColor = Color(.systemGray6)

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
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
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            if !selected.isEmpty {
                attachButton
            }
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground)) // opaque white so the gray tiles have contrast
        .task {
            if allowsImages { recentPhotos.load() }
        }
        .onDisappear { loadTask?.cancel() }
    }

    private var header: some View {
        ZStack {
            Text("Add to Chat")
                .font(.headline)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground), in: .circle)
                        .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()

                if allowsImages {
                    Button {
                        dismiss()
                        onAllPhotos()
                    } label: {
                        Text("All photos")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
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
                    PhotoThumbnailTile(
                        asset: asset,
                        provider: recentPhotos,
                        side: tileSide,
                        placeholderColor: tileColor,
                        isSelected: selected.contains(asset.localIdentifier)
                    ) {
                        toggle(asset)
                    }
                    .disabled(isAttaching)
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
        .background(tileColor, in: .rect(cornerRadius: 16))
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
            .background(tileColor, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var attachButton: some View {
        Button(action: attachSelected) {
            HStack(spacing: 8) {
                if isAttaching {
                    ProgressView()
                        .tint(Color(.systemBackground))
                }
                Text(isAttaching ? "Attaching…" : "Attach \(selected.count) photo\(selected.count == 1 ? "" : "s")")
                    .font(.headline)
            }
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.label), in: .capsule) // concrete color; Color.primary goes vibrant-gray on the inset material
        }
        .buttonStyle(.plain)
        .disabled(isAttaching)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var sheetHeight: CGFloat {
        var height: CGFloat = 60 // header
        if allowsImages { height += tileSide + 28 }
        if allowsFiles { height += 60 }
        height += 76 // reserve the attach-button row so the detent doesn't jump on selection
        return height + 24
    }

    private func toggle(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else {
            selected.append(id)
        }
    }

    private func attachSelected() {
        guard !isAttaching, !selected.isEmpty else { return }
        isAttaching = true
        let assets = selected.compactMap { id in
            recentPhotos.assets.first { $0.localIdentifier == id }
        }
        loadTask = Task {
            var datas: [Data] = []
            for asset in assets {
                if Task.isCancelled { return }
                if let data = await recentPhotos.fullData(for: asset) {
                    datas.append(data)
                }
            }
            guard !Task.isCancelled else { return }
            if datas.isEmpty {
                onPhotoError("Couldn’t attach those photos. Check your connection and try again.")
            } else {
                onPhotosData(datas)
            }
            dismiss()
        }
    }
}

/// One square photo tile. Loads its own thumbnail so the row keeps the newest-first order and only
/// fetches what scrolls into view (the row is a LazyHStack). Shows a spinner while loading, a glyph
/// placeholder if the thumbnail can't be produced, and a checkmark badge when selected.
private struct PhotoThumbnailTile: View {
    let asset: PHAsset
    let provider: RecentPhotos
    let side: CGFloat
    let placeholderColor: Color
    let isSelected: Bool
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
                        placeholderColor
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
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    selectionBadge
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: asset.localIdentifier) {
            image = await provider.thumbnail(for: asset, pixelSide: side * displayScale)
            didLoad = true
        }
    }

    /// A small white circle with a dark check — Claude's selection mark. Fixed colors (not appearance-
    /// adaptive) since it always sits over a photo; a soft shadow keeps it visible on light images.
    private var selectionBadge: some View {
        ZStack {
            Circle().fill(.white)
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.black.opacity(0.8))
        }
        .frame(width: 24, height: 24)
        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
    }
}
