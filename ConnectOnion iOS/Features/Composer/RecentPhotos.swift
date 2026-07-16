import Photos
import SwiftUI
import UIKit

/// Fetches the most recent photos from the library so the attachment sheet can show them inline (like
/// Claude's "Add to Chat"). Thumbnails load per-tile; `fullData` fetches the JPEG when one is picked.
@MainActor
@Observable
final class RecentPhotos {
    var assets: [PHAsset] = []
    var status: PHAuthorizationStatus = .notDetermined

    @ObservationIgnored private let imageManager = PHImageManager.default()

    var isAuthorized: Bool {
        status == .authorized || status == .limited
    }

    func load() {
        Task {
            status = await Self.requestAuthorization()
            guard isAuthorized else { return }
            fetchRecent()
        }
    }

    private func fetchRecent() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 24
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in fetched.append(asset) }
        assets = fetched
    }

    func thumbnail(for asset: PHAsset, side: CGFloat) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat // single callback (opportunistic would resume twice)
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: side * 2, height: side * 2),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func fullData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    nonisolated private static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
