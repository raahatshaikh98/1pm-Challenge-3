//
//  ItemDeletion.swift
//  1pm Challenge 3
//

import Foundation
import Photos

/// Deletes overview items from whichever library they belong to. Photo library
/// items go through PhotoKit, while app files are removed from disk.
enum ItemDeletion {
    struct Outcome {
        var deletedIDs: Set<String>
        var message: String?
    }

    static func delete(_ items: [OverviewItem]) async -> Outcome {
        var deletedIDs = Set<String>()
        var message: String?

        let assetItems = items.filter { $0.assetIdentifier != nil }
        if !assetItems.isEmpty {
            do {
                try await deleteAssets(assetItems)
                deletedIDs.formUnion(assetItems.map(\.id))
            } catch {
                message = error.localizedDescription
            }
        }

        for item in items where item.fileURL != nil {
            guard let url = item.fileURL else { continue }

            do {
                try FileManager.default.removeItem(at: url)
                deletedIDs.insert(item.id)
            } catch {
                message = message ?? "Some files couldn’t be deleted."
            }
        }

        return Outcome(deletedIDs: deletedIDs, message: message)
    }

    private static func deleteAssets(_ items: [OverviewItem]) async throws {
        let identifiers = items.compactMap(\.assetIdentifier)
        guard !identifiers.isEmpty else { return }

        let fetch = PHAsset.fetchAssets(
            withLocalIdentifiers: identifiers,
            options: nil
        )

        var assets: [PHAsset] = []
        assets.reserveCapacity(fetch.count)
        fetch.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        guard !assets.isEmpty else { return }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: error ?? ItemDeletionError.photoLibrary
                    )
                }
            }
        }
    }
}

private enum ItemDeletionError: LocalizedError {
    case photoLibrary

    var errorDescription: String? {
        "The selected photos and videos weren’t deleted."
    }
}
