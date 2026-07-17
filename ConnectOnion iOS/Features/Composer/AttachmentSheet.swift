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
    /// How many photos can still be added (the composer's remaining attachment slots). Selection is
    /// capped to this so the button count is truthful and we never download photos we'll discard.
    var maxPhotoSelection: Int
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
    /// Card fill sampled to match the reference: a clearly-visible neutral light gray on the white
    /// sheet (systemGray6 was too close to white). Adaptive for dark mode.
    private let tileColor = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.17, alpha: 1)
            : UIColor(white: 0.925, alpha: 1)
    })

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if allowsImages {
                photoRow
            }
            if allowsFiles {
                addFilesRow
                    .padding(.horizontal, 16)
            }
            buttonZone
            Spacer(minLength: 0)
        }
        .padding(.bottom, 8)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground)) // opaque white so the gray tiles have contrast
        .task {
            if allowsImages { recentPhotos.load() }
        }
        .onDisappear { loadTask?.cancel() }
    }

    /// The attach button lives in an always-reserved fixed-height slot, so selecting a photo fades the
    /// button in WITHOUT changing the sheet height or resizing the cards above it.
    private var buttonZone: some View {
        ZStack {
            if !selected.isEmpty {
                attachButton
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .animation(.easeInOut(duration: 0.2), value: selected.isEmpty)
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
                    .accessibilityIdentifier(AccessibilityID.chatAttachmentPhotoButton)
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
                    let isSelected = selected.contains(asset.localIdentifier)
                    PhotoThumbnailTile(
                        asset: asset,
                        provider: recentPhotos,
                        side: tileSide,
                        placeholderColor: tileColor,
                        isSelected: isSelected
                    ) {
                        toggle(asset)
                    }
                    // Dim + block the unselected tiles once the remaining-slot cap is reached.
                    .opacity(!isSelected && atCapacity ? 0.4 : 1)
                    .disabled(isAttaching || (!isSelected && atCapacity))
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
        .accessibilityIdentifier(AccessibilityID.chatAttachmentFilesButton)
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
    }

    /// Fixed height that always reserves the attach-button slot, so the sheet never resizes when a
    /// selection appears (the button just fades into its reserved slot). Snug enough to keep the slot
    /// right under "Add files" without a big empty gap.
    private var sheetHeight: CGFloat {
        var height: CGFloat = 60 // header
        if allowsImages { height += 16 + tileSide }
        if allowsFiles { height += 16 + 54 }
        height += 16 + 56 // spacing + reserved attach-button slot (always)
        return height + 12
    }

    private var atCapacity: Bool {
        selected.count >= maxPhotoSelection
    }

    private func toggle(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else if selected.count < maxPhotoSelection {
            selected.append(id)
        }
        // else: already at the remaining-slot cap — ignore (unselected tiles are also disabled)
    }

    private func attachSelected() {
        guard !isAttaching, !selected.isEmpty else { return }
        isAttaching = true
        let assets = selected.compactMap { id in
            recentPhotos.assets.first { $0.localIdentifier == id }
        }
        loadTask = Task {
            var datas: [Data] = []
            var failed = 0
            for asset in assets {
                if Task.isCancelled { return }
                if let data = await recentPhotos.fullData(for: asset) {
                    datas.append(data)
                } else {
                    failed += 1
                }
            }
            guard !Task.isCancelled else { return }
            if !datas.isEmpty {
                onPhotosData(datas)
            }
            if failed > 0 {
                // Surface partial failures too, not just the all-failed case.
                onPhotoError(datas.isEmpty
                    ? "Couldn’t attach those photos. Check your connection and try again."
                    : "\(failed) photo\(failed == 1 ? "" : "s") couldn’t be attached.")
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
