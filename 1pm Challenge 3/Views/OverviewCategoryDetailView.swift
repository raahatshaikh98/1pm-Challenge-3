//
//  OverviewCategoryDetailView.swift
//  1pm Challenge 3
//

import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Informational detail page for one overview category. Management actions
/// are intentionally not included yet; this page only proves the selection
/// and displays the real items, count and storage.
struct OverviewCategoryDetailView: View {
    let kind: StorageCategory
    let usage: OverviewUsage

    private var sortedItems: [OverviewItem] {
        usage.items.sorted {
            ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 6)
                        .padding(.bottom, 24)

                    LazyVStack(spacing: 0) {
                        ForEach(sortedItems) { item in
                            itemRow(item)

                            if item.id != sortedItems.last?.id {
                                Rectangle()
                                    .fill(AppTheme.hairline)
                                    .frame(height: 0.5)
                                    .padding(.leading, 58)
                            }
                        }
                    }

                    Text("Detailed management tools are coming soon.")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle(usage.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(usage.category.color.opacity(0.12))
                    .frame(width: 82, height: 82)

                Circle()
                    .stroke(usage.category.color.opacity(0.2), lineWidth: 1)
                    .frame(width: 82, height: 82)

                Image(systemName: usage.category.symbolName)
                    .font(.system(size: 31, weight: .medium))
                    .foregroundStyle(usage.category.color)
            }

            Text(usage.category.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(usage.formattedSize)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .tracking(-1)
                .monospacedDigit()
                .foregroundStyle(.primary)

            HStack(spacing: 7) {
                Text(usage.itemCount == 1 ? "1 item" : "\(usage.itemCount) items")
                Circle()
                    .fill(AppTheme.tertiaryText)
                    .frame(width: 3, height: 3)
                Text(kind.title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private func itemRow(_ item: OverviewItem) -> some View {
        HStack(spacing: 12) {
            OverviewItemThumbnail(
                item: item,
                tint: usage.category.color
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    if let date = item.date {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                    Text("·")
                    Text(item.formattedSize)
                        .monospacedDigit()
                }
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct OverviewItemThumbnail: View {
    let item: OverviewItem
    let tint: Color

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipped()
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: item.id) {
            await loadThumbnail()
        }
    }

    private var placeholderSymbol: String {
        if item.fileURL != nil { return "doc.fill" }
        return item.isVideo ? "video.fill" : "photo.fill"
    }

    private func loadThumbnail() async {
        if let identifier = item.assetIdentifier {
            image = await PhotoThumbnailLoader.load(identifier: identifier)
        } else if let url = item.fileURL, isImageFile(url) {
            image = await Task.detached(priority: .utility) {
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }

    private func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }
}

private enum PhotoThumbnailLoader {
    static func load(identifier: String) async -> UIImage? {
        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        guard let asset = assets.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let gate = ThumbnailGate(continuation)
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 140, height: 140),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                gate.finish(image)
            }
        }
    }
}

private final class ThumbnailGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private var isFinished = false

    init(_ continuation: CheckedContinuation<UIImage?, Never>) {
        self.continuation = continuation
    }

    func finish(_ image: UIImage?) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()

        continuation?.resume(returning: image)
    }
}
