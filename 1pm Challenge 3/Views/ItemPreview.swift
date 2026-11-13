//
//  ItemPreview.swift
//  1pm Challenge 3
//

import Foundation
import Photos
import QuickLook
import SwiftUI

/// One request to preview an item inside a list. Every tap creates a new
/// request, so tapping the same row twice still reopens QuickLook.
struct ItemPreviewRequest: Identifiable {
    let id = UUID()
    let items: [OverviewItem]
    let startIndex: Int
}

/// The local files QuickLook should show, plus the temporary folder (if any)
/// that has to be removed once the preview is dismissed.
struct PreparedPreview {
    var urls: [URL]
    var startIndex: Int
    var directory: URL?
}

/// Turns overview items into file URLs QuickLook can read. Files already in
/// the app's Documents folder are previewed in place. Photo library items are
/// exported to a temporary folder first, because PhotoKit never exposes their
/// original file URL directly.
enum ItemPreviewResolver {
    static func prepare(_ request: ItemPreviewRequest) async throws -> PreparedPreview {
        let items = request.items

        guard items.indices.contains(request.startIndex) else {
            throw ItemPreviewError.missingItem
        }

        let target = items[request.startIndex]

        // Files already live on disk, so the whole category can swipe through
        // in one QuickLook session.
        if items.allSatisfy({ $0.fileURL != nil }) {
            let urls = items
                .compactMap(\.fileURL)
                .filter { FileManager.default.fileExists(atPath: $0.path) }

            guard let targetURL = target.fileURL,
                  let index = urls.firstIndex(of: targetURL) else {
                throw ItemPreviewError.missingFile
            }

            return PreparedPreview(urls: urls, startIndex: index, directory: nil)
        }

        // Library assets have no URL until they are exported. Only the tapped
        // item is prepared, because videos can be several gigabytes.
        guard let identifier = target.assetIdentifier else {
            throw ItemPreviewError.missingItem
        }

        let directory = try makeTemporaryDirectory()

        do {
            let url = try await AssetPreviewExporter.export(
                identifier: identifier,
                fallbackName: target.name,
                isVideo: target.isVideo,
                into: directory
            )
            return PreparedPreview(urls: [url], startIndex: 0, directory: directory)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ItemPreviews", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }
}

// MARK: - Photo library export

private enum AssetPreviewExporter {
    static func export(
        identifier: String,
        fallbackName: String,
        isVideo: Bool,
        into directory: URL
    ) async throws -> URL {
        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )

        guard let asset = assets.firstObject else {
            throw ItemPreviewError.missingItem
        }

        let resources = PHAssetResource.assetResources(for: asset)
        let preferredTypes: [PHAssetResourceType] = isVideo
            ? [.fullSizeVideo, .video]
            : [.fullSizePhoto, .photo, .alternatePhoto]

        guard let resource = preferredTypes
            .compactMap({ type in resources.first { $0.type == type } })
            .first else {
            throw ItemPreviewError.missingResource
        }

        let name = resource.originalFilename.isEmpty
            ? fallbackName
            : resource.originalFilename
        let destination = directory.appendingPathComponent(
            safeFilename(name, isVideo: isVideo)
        )

        // iCloud-only items are downloaded on demand so they can be previewed
        // even when the original is not on this iPhone yet.
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(
                for: resource,
                toFile: destination,
                options: options
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return destination
    }

    /// QuickLook relies on the file extension to pick a viewer, so every
    /// exported file keeps (or gets) a sensible one.
    private static func safeFilename(_ name: String, isVideo: Bool) -> String {
        let trimmed = (name as NSString).lastPathComponent
        let base = trimmed.isEmpty
            ? (isVideo ? "Preview.mov" : "Preview.jpg")
            : trimmed

        if (base as NSString).pathExtension.isEmpty {
            return base + (isVideo ? ".mov" : ".jpg")
        }
        return base
    }
}

// MARK: - Errors

private enum ItemPreviewError: LocalizedError {
    case missingItem
    case missingFile
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingItem:
            return "This item is no longer available."
        case .missingFile:
            return "This file couldn’t be found on this iPhone."
        case .missingResource:
            return "This item can’t be previewed right now."
        }
    }
}

// MARK: - SwiftUI integration

extension View {
    /// Adds QuickLook previewing to any page that lists overview items.
    func itemPreview(request: Binding<ItemPreviewRequest?>) -> some View {
        modifier(ItemPreviewModifier(request: request))
    }
}

private struct ItemPreviewModifier: ViewModifier {
    @Binding var request: ItemPreviewRequest?

    @State private var urls: [URL] = []
    @State private var selection: URL?
    @State private var sessionDirectory: URL?
    @State private var isPreparing = false
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .quickLookPreview($selection, in: urls)
            .overlay {
                if isPreparing {
                    preparingOverlay
                        .transition(.opacity)
                }
            }
            .alert(
                "Couldn’t preview item",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task(id: request?.id) {
                guard let request else { return }
                await prepare(request)
            }
            .onChange(of: selection) { _, newValue in
                // QuickLook clears its selection when the sheet is dismissed,
                // which is the moment the exported copies can be removed.
                if newValue == nil {
                    cleanup()
                }
            }
    }

    private var preparingOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.secondaryText)

                Text("Preparing preview…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @MainActor
    private func prepare(_ request: ItemPreviewRequest) async {
        cleanup()
        isPreparing = true
        defer { isPreparing = false }

        do {
            let prepared = try await ItemPreviewResolver.prepare(request)

            guard !Task.isCancelled else {
                if let directory = prepared.directory {
                    try? FileManager.default.removeItem(at: directory)
                }
                return
            }

            sessionDirectory = prepared.directory
            urls = prepared.urls
            selection = prepared.urls[prepared.startIndex]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cleanup() {
        if let sessionDirectory {
            try? FileManager.default.removeItem(at: sessionDirectory)
        }

        sessionDirectory = nil
        urls = []
        selection = nil
    }
}
