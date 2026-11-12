//
//  OverviewScanner.swift
//  1pm Challenge 3
//

import AVFoundation
import CryptoKit
import Foundation
import ImageIO
import Photos
import Vision

/// Reads the real photo library and the app's visible folders. Each item is
/// measured once and carries flags, so the view model can place it in several
/// categories without re-reading the item. All work happens off the main
/// thread and checks `Task.isCancelled` between items.
enum OverviewScanner {
    typealias ProgressHandler = @Sendable (Double) async -> Void

    static func scan(
        kind: StorageCategory,
        progress: @escaping ProgressHandler
    ) async -> OverviewScanResult {
        switch kind {
        case .photos, .videos:
            return await scanMedia(kind: kind, progress: progress)
        case .files:
            return await scanFiles(progress: progress)
        }
    }

    // MARK: - Photos and videos

    private static func scanMedia(
        kind: StorageCategory,
        progress: @escaping ProgressHandler
    ) async -> OverviewScanResult {
        let access = accessState(from: PHPhotoLibrary.authorizationStatus(for: .readWrite))

        guard access == .authorized || access == .limited else {
            return .empty(accessState: access)
        }

        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.includeAllBurstAssets = false

        let fetch = PHAsset.fetchAssets(
            with: kind == .photos ? .image : .video,
            options: options
        )

        var assets: [PHAsset] = []
        assets.reserveCapacity(fetch.count)
        fetch.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        guard !assets.isEmpty else {
            return .empty(accessState: access)
        }

        var items: [OverviewItem] = []
        items.reserveCapacity(assets.count)
        var seenDigests = Set<String>()
        var skippedItems = 0

        for (index, asset) in assets.enumerated() {
            if Task.isCancelled { break }

            if kind == .photos {
                guard let measured = await loadPhoto(asset) else {
                    skippedItems += 1
                    await report(index: index, total: assets.count, progress: progress)
                    continue
                }

                let isDuplicate = seenDigests.contains(measured.digest)
                seenDigests.insert(measured.digest)

                let image = measured.data.flatMap(thumbnailImage(from:))

                items.append(
                    OverviewItem(
                        id: asset.localIdentifier,
                        name: measured.name,
                        bytes: measured.bytes,
                        date: asset.creationDate,
                        assetIdentifier: asset.localIdentifier,
                        fileURL: nil,
                        isVideo: false,
                        isScreenshot: measured.isScreenshot,
                        hasQRCode: image.map(containsQRCode) ?? false,
                        isBlurry: image.map(isBlurry) ?? false,
                        isDuplicate: isDuplicate
                    )
                )

            } else {
                guard let measured = await measureVideo(asset) else {
                    skippedItems += 1
                    await report(index: index, total: assets.count, progress: progress)
                    continue
                }

                let isDuplicate = seenDigests.contains(measured.digest)
                seenDigests.insert(measured.digest)

                items.append(
                    OverviewItem(
                        id: asset.localIdentifier,
                        name: measured.name,
                        bytes: measured.bytes,
                        date: asset.creationDate,
                        assetIdentifier: asset.localIdentifier,
                        fileURL: nil,
                        isVideo: true,
                        isDuplicate: isDuplicate,
                        isScreenRecording: measured.isScreenRecording
                    )
                )
            }

            await report(index: index, total: assets.count, progress: progress)
        }

        return OverviewScanResult(
            items: items,
            accessState: access,
            skippedItems: skippedItems
        )
    }

    private struct PhotoMeasurement {
        var bytes: Int64
        var digest: String
        var data: Data?
        var name: String
        var isScreenshot: Bool
    }

    private static func loadPhoto(_ asset: PHAsset) async -> PhotoMeasurement? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .fullSizePhoto })
            ?? resources.first(where: { $0.type == .photo }) else {
            return nil
        }

        // Fetching the original data gives an exact byte count, an exact hash
        // for duplicate detection, and the pixels Vision needs. iCloud items
        // are downloaded on demand; the scan stays cancellable throughout.
        guard let measured = await loadResourceData(
            resource,
            allowNetwork: true,
            keepData: true
        ), measured.bytes > 0 else {
            return nil
        }

        return PhotoMeasurement(
            bytes: measured.bytes,
            digest: measured.digest,
            data: measured.data,
            name: resource.originalFilename,
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
        )
    }

    private struct VideoMeasurement {
        var bytes: Int64
        var digest: String
        var name: String
        var isScreenRecording: Bool
    }

    private static func measureVideo(_ asset: PHAsset) async -> VideoMeasurement? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .fullSizeVideo })
            ?? resources.first(where: { $0.type == .video }) else {
            return nil
        }

        let name = resource.originalFilename
        var bytes: Int64?

        // A normal local video can be measured from its AVURLAsset without
        // reading the whole file. Live Photo paired videos and some sandboxed
        // assets do not expose a URL, so fall back to counting the bytes that
        // PhotoKit streams to us.
        if let url = await videoURL(for: asset),
           let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = (attributes[.size] as? NSNumber)?.int64Value,
           size > 0 {
            bytes = size
        } else if let measured = await loadResourceData(
            resource,
            allowNetwork: false,
            keepData: false
        ), measured.bytes > 0 {
            bytes = measured.bytes
        }

        guard let bytes else { return nil }

        // Comparing the same stable metadata for both measurement paths keeps
        // duplicate detection consistent without reading every video twice.
        let durationMilliseconds = Int((asset.duration * 1000).rounded())
        let fingerprint = "\(bytes)|\(durationMilliseconds)|\(asset.pixelWidth)x\(asset.pixelHeight)"
        let digest = SHA256.hash(data: Data(fingerprint.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return VideoMeasurement(
            bytes: bytes,
            digest: digest,
            name: name,
            isScreenRecording: asset.mediaSubtypes.contains(.videoScreenRecording)
        )
    }

    private static func videoURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .fastFormat

            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: options
            ) { avAsset, _, _ in
                continuation.resume(
                    returning: (avAsset as? AVURLAsset)?.url
                )
            }
        }
    }

    private static func report(
        index: Int,
        total: Int,
        progress: @escaping ProgressHandler
    ) async {
        guard total > 0 else { return }
        guard index % 8 == 0 || index == total - 1 else { return }
        await progress(Double(index + 1) / Double(total))
    }

    // MARK: - Files

    private static func collectFileURLs(
        in documents: URL,
        keys: Set<URLResourceKey>
    ) -> [URL] {
        var urls: [URL] = []

        guard let enumerator = FileManager.default.enumerator(
            at: documents,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return urls
        }

        for case let url as URL in enumerator {
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else {
                continue
            }
            urls.append(url)
        }

        return urls
    }

    private static func scanFiles(
        progress: @escaping ProgressHandler
    ) async -> OverviewScanResult {
        guard let documents = try? DocumentLibrary.documentsDirectory() else {
            return .empty(accessState: .notApplicable)
        }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        let urls = collectFileURLs(in: documents, keys: keys)

        guard !urls.isEmpty else {
            return .empty(accessState: .notApplicable)
        }

        var items: [OverviewItem] = []
        items.reserveCapacity(urls.count)
        var seenDigests = Set<String>()

        for (index, url) in urls.enumerated() {
            if Task.isCancelled { break }

            guard let values = try? url.resourceValues(forKeys: keys) else {
                continue
            }

            let bytes = Int64(
                values.totalFileAllocatedSize
                    ?? values.fileAllocatedSize
                    ?? values.fileSize
                    ?? 0
            )
            let date = values.contentModificationDate
            let digest = fileDigest(url)
            let isDuplicate = digest.map { seenDigests.contains($0) } ?? false
            if let digest { seenDigests.insert(digest) }

            let isDownload = url.pathComponents
                .dropLast()
                .contains { $0.caseInsensitiveCompare("Downloads") == .orderedSame }

            items.append(
                OverviewItem(
                    id: url.path,
                    name: url.lastPathComponent,
                    bytes: bytes,
                    date: date,
                    assetIdentifier: nil,
                    fileURL: url,
                    isVideo: false,
                    isDuplicate: isDuplicate,
                    isDownload: isDownload
                )
            )

            if index % 10 == 0 || index == urls.count - 1 {
                await progress(Double(index + 1) / Double(urls.count))
            }
        }

        return OverviewScanResult(
            items: items,
            accessState: .notApplicable,
            skippedItems: 0
        )
    }

    private static func accessState(from status: PHAuthorizationStatus) -> PhotoAccessState {
        switch status {
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    // MARK: - Image analysis

    private static func thumbnailImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024
        ]

        return CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        )
    }

    private static func containsQRCode(_ image: CGImage) -> Bool {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        do {
            try VNImageRequestHandler(
                cgImage: image,
                orientation: .up
            ).perform([request])
        } catch {
            return false
        }

        return !(request.results?.isEmpty ?? true)
    }

    /// Vision does not expose a public sharpness score, so this uses a
    /// conservative normalised gradient measure. A low average difference
    /// between neighbouring pixels indicates an image with almost no detail.
    private static func isBlurry(_ image: CGImage) -> Bool {
        let width = 128
        let height = 128
        var pixels = [UInt8](repeating: 0, count: width * height)

        let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else {
                return false
            }

            context.interpolationQuality = .medium
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            return true
        }

        guard didDraw else { return false }

        var total = 0.0
        for y in 0..<height {
            for x in 1..<width {
                total += abs(
                    Double(pixels[y * width + x])
                        - Double(pixels[y * width + x - 1])
                )
            }
        }
        for y in 1..<height {
            for x in 0..<width {
                total += abs(
                    Double(pixels[y * width + x])
                        - Double(pixels[(y - 1) * width + x])
                )
            }
        }

        let sampleCount = Double((width - 1) * height + (height - 1) * width)
        let averageGradient = total / sampleCount / 255
        return averageGradient < 0.018
    }

    // MARK: - File hashing

    private static func fileDigest(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        var hasher = SHA256()

        while true {
            if Task.isCancelled { return nil }

            guard let chunk = try? handle.read(upToCount: 1 << 20),
                  !chunk.isEmpty else {
                break
            }
            hasher.update(data: chunk)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Streaming PhotoKit data

    private static func loadResourceData(
        _ resource: PHAssetResource,
        allowNetwork: Bool,
        keepData: Bool
    ) async -> (bytes: Int64, digest: String, data: Data?)? {
        let collector = StreamingCollector(keepData: keepData)
        let gate = ResourceDataGate()

        let succeeded = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                gate.setContinuation(continuation)

                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = allowNetwork

                let requestID = PHAssetResourceManager.default().requestData(
                    for: resource,
                    options: options,
                    dataReceivedHandler: { chunk in
                        collector.append(chunk)
                    },
                    completionHandler: { error in
                        gate.finish(success: error == nil)
                    }
                )

                gate.setRequestID(requestID)
            }
        } onCancel: {
            gate.cancel()
        }

        guard succeeded else { return nil }
        return collector.result()
    }
}

// MARK: - Small thread-safe helpers

private final class ResourceDataGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?
    private var requestID: PHAssetResourceDataRequestID?
    private var isCancelled = false
    private var isFinished = false

    func setContinuation(_ continuation: CheckedContinuation<Bool, Never>) {
        lock.lock()
        if isFinished {
            lock.unlock()
            continuation.resume(returning: false)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func setRequestID(_ requestID: PHAssetResourceDataRequestID) {
        lock.lock()
        self.requestID = requestID
        let cancelNow = isCancelled
        lock.unlock()

        if cancelNow {
            PHAssetResourceManager.default().cancelDataRequest(requestID)
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let id = requestID
        lock.unlock()

        if let id {
            PHAssetResourceManager.default().cancelDataRequest(id)
        }
    }

    func finish(success: Bool) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(returning: success)
    }
}

private final class StreamingCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let keepData: Bool
    private var hasher = SHA256()
    private var data = Data()
    private var byteCount: Int64 = 0

    init(keepData: Bool) {
        self.keepData = keepData
    }

    func append(_ chunk: Data) {
        lock.lock()
        byteCount += Int64(chunk.count)
        hasher.update(data: chunk)
        if keepData {
            data.append(chunk)
        }
        lock.unlock()
    }

    func result() -> (bytes: Int64, digest: String, data: Data?) {
        lock.lock()
        let bytes = byteCount
        let keptData = keepData ? data : nil
        let copy = hasher
        let digest = copy.finalize()
        lock.unlock()

        return (
            bytes,
            digest.map { String(format: "%02x", $0) }.joined(),
            keptData
        )
    }
}
