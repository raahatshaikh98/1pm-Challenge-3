//
//  StorageStore.swift
//  1pm Challenge 3
//

import Foundation
import Photos

/// Collects only measurements the app is actually allowed to make:
/// device capacity, this app's document files, and the user's photo library.
/// It never walks the whole filesystem and never invents missing values.
final class StorageStore: ObservableObject {
    @Published private(set) var snapshot: StorageSnapshot = .loading

    private var isRefreshing = false
    private var lastRefresh: Date?
    private var lastAuthorizationStatus: PHAuthorizationStatus?

    @MainActor
    func refresh(requestAccess: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let capacity = Self.deviceCapacity()
        let fileBytes = await Self.appFileBytes()

        let authorization: PHAuthorizationStatus
        if requestAccess {
            authorization = await Self.photoAuthorizationStatus()
        } else {
            authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
        lastAuthorizationStatus = authorization

        let photos: CategoryUsage
        let videos: CategoryUsage

        switch authorization {
        case .authorized, .limited:
            let media = await Self.measureMediaLibrary()
            let isLimited = authorization == .limited

            photos = CategoryUsage(
                category: .photos,
                bytes: media.photos.bytes,
                quality: Self.quality(complete: media.photos.complete, isLimited: isLimited),
                note: Self.mediaNote(complete: media.photos.complete, isLimited: isLimited)
            )
            videos = CategoryUsage(
                category: .videos,
                bytes: media.videos.bytes,
                quality: Self.quality(complete: media.videos.complete, isLimited: isLimited),
                note: Self.mediaNote(complete: media.videos.complete, isLimited: isLimited)
            )

        case .denied, .restricted:
            let note = "Photo access is off. Allow access in Settings to measure your photo and video library."
            photos = CategoryUsage(category: .photos, bytes: 0, quality: .unavailable, note: note)
            videos = CategoryUsage(category: .videos, bytes: 0, quality: .unavailable, note: note)

        case .notDetermined:
            let note = "Photo access has not been granted yet."
            photos = CategoryUsage(category: .photos, bytes: 0, quality: .unavailable, note: note)
            videos = CategoryUsage(category: .videos, bytes: 0, quality: .unavailable, note: note)

        @unknown default:
            let note = "Photo access is unavailable on this device."
            photos = CategoryUsage(category: .photos, bytes: 0, quality: .unavailable, note: note)
            videos = CategoryUsage(category: .videos, bytes: 0, quality: .unavailable, note: note)
        }

        let files = CategoryUsage(
            category: .files,
            bytes: fileBytes,
            quality: .verified,
            note: "Measured from files in On My iPhone › 1pm Challenge 3."
        )

        snapshot = StorageSnapshot(
            totalCapacity: capacity.total,
            usedCapacity: capacity.used,
            categories: [photos, videos, files],
            isLoaded: true,
            isPhotoAccessLimited: authorization == .limited
        )
        lastRefresh = Date()
    }

    /// Refreshes when access changed, on first launch, or after the values
    /// have gone stale. Returning from the app switcher does not trigger a
    /// needless full rescan.
    @MainActor
    func refreshIfNeeded() async {
        let currentAuthorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let isStale = lastRefresh.map { Date().timeIntervalSince($0) > 300 } ?? true

        guard !snapshot.isLoaded || currentAuthorization != lastAuthorizationStatus || isStale else {
            return
        }

        await refresh(requestAccess: false)
    }

    /// Asks for photo access if the user has never answered the system prompt.
    /// If access was already denied, the caller should send the user to Settings.
    @MainActor
    func requestPhotoAccess() async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else {
            await refresh()
            return
        }

        _ = await Self.photoAuthorizationStatus()
        await refresh()
    }

    // MARK: - Photo library

    private static func photoAuthorizationStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func measureMediaLibrary() async -> MediaMeasurement {
        await Task.detached(priority: .utility) {
            let options = PHFetchOptions()
            options.includeHiddenAssets = false
            options.includeAllBurstAssets = false

            let photoAssets = PHAsset.fetchAssets(with: .image, options: options)
            let videoAssets = PHAsset.fetchAssets(with: .video, options: options)

            return MediaMeasurement(
                photos: measure(assets: photoAssets),
                videos: measure(assets: videoAssets)
            )
        }.value
    }

    private static func measure(assets: PHFetchResult<PHAsset>) -> MediaBucket {
        var bytes: Int64 = 0
        var complete = true

        assets.enumerateObjects { asset, _, _ in
            autoreleasepool {
                let resources = PHAssetResource.assetResources(for: asset)
                let isVideo = asset.mediaType == .video
                let primaryType: PHAssetResourceType = isVideo ? .fullSizeVideo : .fullSizePhoto
                let fallbackType: PHAssetResourceType = isVideo ? .video : .photo

                guard let resource = resources.first(where: { $0.type == primaryType })
                    ?? resources.first(where: { $0.type == fallbackType }) else {
                    complete = false
                    return
                }

                guard let size = resource.measuredFileSize else {
                    complete = false
                    return
                }
                bytes += size

                // A Live Photo is a still plus a short paired video. Count the
                // paired portion when PhotoKit can report it.
                if !isVideo,
                   asset.mediaSubtypes.contains(.photoLive),
                   let pairedVideo = resources.first(where: { $0.type == .pairedVideo }) {
                    if let pairedSize = pairedVideo.measuredFileSize {
                        bytes += pairedSize
                    } else {
                        complete = false
                    }
                }
            }
        }

        return MediaBucket(bytes: bytes, complete: complete)
    }

    private static func quality(complete: Bool, isLimited: Bool) -> MeasurementQuality {
        (isLimited || !complete) ? .estimated : .verified
    }

    private static func mediaNote(complete: Bool, isLimited: Bool) -> String? {
        if isLimited {
            return "Limited photo access. Only the items you allowed are measured, so this total may be incomplete."
        }
        if !complete {
            return "Some items could not be read from iCloud, so this total may be lower than the value in Settings."
        }
        return nil
    }

    // MARK: - Device and app files

    private static func deviceCapacity() -> (total: Int64?, used: Int64?) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]

        if let values = try? home.resourceValues(forKeys: keys),
           let total = values.volumeTotalCapacity {
            // Use plain available capacity, not the "important usage" value.
            // The latter includes purgeable space and makes "used" look much
            // larger than the figure shown in Settings.
            let available = values.volumeAvailableCapacity.map { Int64($0) }
            return (
                Int64(total),
                available.map { max(0, Int64(total) - $0) }
            )
        }

        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let total = (attributes[.systemSize] as? NSNumber)?.int64Value {
            let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value
            return (total, free.map { max(0, total - $0) })
        }

        return (nil, nil)
    }

    private static func appFileBytes() async -> Int64 {
        await Task.detached(priority: .utility) {
            measuredDocumentBytes()
        }.value
    }

    /// Kept synchronous so the directory enumerator is never traversed from
    /// an async context. The caller runs it on a background task.
    private static func measuredDocumentBytes() -> Int64 {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0
        }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: documents,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }

            let size = values.totalFileAllocatedSize
                ?? values.fileAllocatedSize
                ?? values.fileSize
                ?? 0
            total += Int64(size)
        }
        return total
    }
}

// MARK: - Private measurement types

private struct MediaBucket: Sendable {
    var bytes: Int64
    var complete: Bool
}

private struct MediaMeasurement: Sendable {
    var photos: MediaBucket
    var videos: MediaBucket
}

private extension PHAssetResource {
    /// PhotoKit does not publish a public size property. Reading the resource's
    /// `fileSize` key is the least invasive way to obtain the actual local size;
    /// when it is unavailable the category is reported as estimated instead.
    var measuredFileSize: Int64? {
        let selector = NSSelectorFromString("fileSize")
        guard responds(to: selector),
              let number = value(forKey: "fileSize") as? NSNumber else {
            return nil
        }

        let size = number.int64Value
        return size > 0 ? size : nil
    }
}
