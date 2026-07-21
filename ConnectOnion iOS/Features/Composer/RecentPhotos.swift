//
//  RecentPhotos.swift
//
//  Purpose: Implements RecentPhotos for the Features/Composer module.
//  Collaborates with: AttachmentSheet, AttachmentStrip, CameraPicker, ChatInputBar, ComposerAttachmentPreviews, SkillCommandPalette.
//  References: Apple Swift documentation (https://developer.apple.com/documentation/swift) and
//               the project architecture described in README.md where applicable.
//
//  This file is part of the ConnectOnion iOS application.
//
import Photos
import SwiftUI
import UIKit

/// Fetches the most recent photos from the library so the attachment sheet can show them inline (like
/// Claude's "Add to Chat"). Thumbnails load per-tile (local-only); `fullData` fetches the JPEG when one
/// is picked (allowing an iCloud download for that single explicit choice).
@MainActor
@Observable
final class RecentPhotos {
    var assets: [PHAsset] = []
    var status: PHAuthorizationStatus = .notDetermined

    @ObservationIgnored private let imageManager = PHImageManager.default()

    var isAuthorized: Bool { status == .authorized || status == .limited }
    var isDenied: Bool { status == .denied || status == .restricted }

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

    /// Thumbnail for one tile. `pixelSide` is already in pixels (point size × display scale).
    /// Network access is off — the row shows many at once, so a missing iCloud original falls back to
    /// its on-device thumbnail rather than pulling full data for every tile.
    func thumbnail(for asset: PHAsset, pixelSide: CGFloat) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat // single callback + crisp (fastFormat looked blurry)
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = false
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: pixelSide, height: pixelSide),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Full JPEG for the tapped photo. Allows an iCloud download since it's a single explicit pick.
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
