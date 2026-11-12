//
//  OverviewModels.swift
//  1pm Challenge 3
//

import SwiftUI

/// Every breakdown a category page can show. An item can belong to more than
/// one category (for example an old large video), so membership is derived
/// from per-item flags instead of a single priority assignment.
enum OverviewCategory: String, CaseIterable, Identifiable, Hashable {
    case largePhotos
    case outdatedPhotos
    case blurryPhotos
    case duplicatePhotos
    case screenshots
    case qrCodes

    case largeVideos
    case outdatedVideos
    case duplicateVideos
    case screenRecordings

    case largeFiles
    case outdatedFiles
    case duplicateFiles
    case downloads

    var id: String { rawValue }

    var kind: StorageCategory {
        switch self {
        case .largePhotos, .outdatedPhotos, .blurryPhotos,
             .duplicatePhotos, .screenshots, .qrCodes:
            return .photos
        case .largeVideos, .outdatedVideos, .duplicateVideos, .screenRecordings:
            return .videos
        case .largeFiles, .outdatedFiles, .duplicateFiles, .downloads:
            return .files
        }
    }

    /// Full name, used by the filter sheet and detail page.
    var title: String {
        switch self {
        case .largePhotos:
            return "Large Photos"
        case .outdatedPhotos:
            return "Outdated Photos"
        case .blurryPhotos:
            return "Blurry Photos"
        case .duplicatePhotos:
            return "Duplicate Photos"
        case .screenshots:
            return "Screenshots"
        case .qrCodes:
            return "QR Codes"
        case .largeVideos:
            return "Large Videos"
        case .outdatedVideos:
            return "Outdated Videos"
        case .duplicateVideos:
            return "Duplicate Videos"
        case .screenRecordings:
            return "Screen Recordings"
        case .largeFiles:
            return "Large Files"
        case .outdatedFiles:
            return "Outdated Files"
        case .duplicateFiles:
            return "Duplicate Files"
        case .downloads:
            return "Downloads"
        }
    }

    /// Compact name for the two-column legend.
    var shortTitle: String {
        switch self {
        case .largePhotos, .largeVideos, .largeFiles:
            return "Large"
        case .outdatedPhotos, .outdatedVideos, .outdatedFiles:
            return "Outdated"
        case .blurryPhotos:
            return "Blurry"
        case .duplicatePhotos, .duplicateVideos, .duplicateFiles:
            return "Duplicates"
        case .screenshots:
            return "Screenshots"
        case .qrCodes:
            return "QR Codes"
        case .screenRecordings:
            return "Recordings"
        case .downloads:
            return "Downloads"
        }
    }

    var symbolName: String {
        switch self {
        case .largePhotos:
            return "photo.fill"
        case .outdatedPhotos:
            return "clock.arrow.circlepath"
        case .blurryPhotos:
            return "camera.filters"
        case .duplicatePhotos:
            return "square.on.square"
        case .screenshots:
            return "camera.viewfinder"
        case .qrCodes:
            return "qrcode"
        case .largeVideos:
            return "video.fill"
        case .outdatedVideos:
            return "clock.arrow.circlepath"
        case .duplicateVideos:
            return "square.on.square"
        case .screenRecordings:
            return "record.circle"
        case .largeFiles:
            return "doc.fill"
        case .outdatedFiles:
            return "clock.arrow.circlepath"
        case .duplicateFiles:
            return "square.on.square"
        case .downloads:
            return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .largePhotos:
            return AppTheme.dynamic(light: 0x7C5CFC, dark: 0xA78BFA)
        case .outdatedPhotos:
            return AppTheme.dynamic(light: 0x4F8EF7, dark: 0x60A5FA)
        case .blurryPhotos:
            return AppTheme.dynamic(light: 0x14B8A6, dark: 0x2DD4BF)
        case .duplicatePhotos:
            return AppTheme.dynamic(light: 0xEC4899, dark: 0xF472B6)
        case .screenshots:
            return AppTheme.dynamic(light: 0xD97706, dark: 0xFBBF24)
        case .qrCodes:
            return AppTheme.dynamic(light: 0x059669, dark: 0x34D399)
        case .largeVideos:
            return AppTheme.dynamic(light: 0x0891B2, dark: 0x22D3EE)
        case .outdatedVideos:
            return AppTheme.dynamic(light: 0x4F8EF7, dark: 0x60A5FA)
        case .duplicateVideos:
            return AppTheme.dynamic(light: 0x7C5CFC, dark: 0xA78BFA)
        case .screenRecordings:
            return AppTheme.dynamic(light: 0xDC2626, dark: 0xF87171)
        case .largeFiles:
            return AppTheme.dynamic(light: 0xD97706, dark: 0xFBBF24)
        case .outdatedFiles:
            return AppTheme.dynamic(light: 0xEA580C, dark: 0xFB923C)
        case .duplicateFiles:
            return AppTheme.dynamic(light: 0xE11D48, dark: 0xFB7185)
        case .downloads:
            return AppTheme.dynamic(light: 0x059669, dark: 0x34D399)
        }
    }

    static func categories(for kind: StorageCategory) -> [OverviewCategory] {
        allCases.filter { $0.kind == kind }
    }

    static func outdatedCategory(for kind: StorageCategory) -> OverviewCategory {
        switch kind {
        case .photos:
            return .outdatedPhotos
        case .videos:
            return .outdatedVideos
        case .files:
            return .outdatedFiles
        }
    }

    static func largeThreshold(for kind: StorageCategory) -> Int64 {
        switch kind {
        case .photos:
            return 2_000_000
        case .videos:
            return 25_000_000
        case .files:
            return 10_000_000
        }
    }

    /// An item can match several categories. The chart de-duplicates bytes for
    /// its centre total, while each category still lists every matching item.
    func matches(_ item: OverviewItem, cutoff: Date) -> Bool {
        switch self {
        case .largePhotos, .largeVideos, .largeFiles:
            return item.bytes >= OverviewCategory.largeThreshold(for: kind)
        case .outdatedPhotos, .outdatedVideos, .outdatedFiles:
            guard let date = item.date else { return false }
            return date < cutoff
        case .blurryPhotos:
            return item.isBlurry
        case .duplicatePhotos, .duplicateVideos, .duplicateFiles:
            return item.isDuplicate
        case .screenshots:
            return item.isScreenshot
        case .qrCodes:
            return item.hasQRCode
        case .screenRecordings:
            return item.isScreenRecording
        case .downloads:
            return item.isDownload
        }
    }
}

/// How old an item has to be before it counts as outdated. Changing this only
/// reclassifies existing scan results, so no rescan is needed.
enum OutdatedThreshold: Int, CaseIterable, Identifiable {
    case oneMonth = 1
    case threeMonths = 3
    case sixMonths = 6
    case oneYear = 12
    case threeYears = 36

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneMonth:
            return "1 month"
        case .threeMonths:
            return "3 months"
        case .sixMonths:
            return "6 months"
        case .oneYear:
            return "1 year"
        case .threeYears:
            return "3 years"
        }
    }

    var cutoff: Date {
        Calendar.current.date(byAdding: .month, value: -rawValue, to: Date())
            ?? Date().addingTimeInterval(-Double(rawValue) * 30 * 24 * 60 * 60)
    }
}

/// One media item or file inside an overview category. Only descriptors are
/// kept in memory; image data is fetched lazily by the detail page.
struct OverviewItem: Identifiable, Hashable {
    let id: String
    let name: String
    let bytes: Int64
    let date: Date?
    let assetIdentifier: String?
    let fileURL: URL?
    let isVideo: Bool

    var isScreenshot: Bool = false
    var hasQRCode: Bool = false
    var isBlurry: Bool = false
    var isDuplicate: Bool = false
    var isScreenRecording: Bool = false
    var isDownload: Bool = false

    var formattedSize: String {
        StorageFormatter.compact(bytes)
    }
}

struct OverviewUsage: Identifiable, Hashable {
    let category: OverviewCategory
    var bytes: Int64
    var items: [OverviewItem]

    var id: OverviewCategory { category }
    var itemCount: Int { items.count }

    var formattedSize: String {
        StorageFormatter.compact(bytes)
    }
}

enum PhotoAccessState: Equatable {
    case notApplicable
    case notDetermined
    case denied
    case limited
    case authorized

    var needsPermission: Bool {
        self == .notDetermined || self == .denied
    }

    var isLimited: Bool {
        self == .limited
    }
}

struct OverviewScanResult {
    var items: [OverviewItem]
    var accessState: PhotoAccessState
    var skippedItems: Int

    static func empty(accessState: PhotoAccessState) -> OverviewScanResult {
        OverviewScanResult(items: [], accessState: accessState, skippedItems: 0)
    }
}
