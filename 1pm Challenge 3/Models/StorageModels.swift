//
//  StorageModels.swift
//  1pm Challenge 3
//

import SwiftUI

enum StorageCategory: String, CaseIterable, Identifiable, Hashable {
    case photos
    case videos
    case files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photos:
            return "Photos"
        case .videos:
            return "Videos"
        case .files:
            return "Files"
        }
    }

    var symbolName: String {
        switch self {
        case .photos:
            return "photo.stack"
        case .videos:
            return "video.fill"
        case .files:
            return "folder.fill"
        }
    }

    var color: Color {
        switch self {
        case .photos:
            return AppTheme.dynamic(light: 0x7C5CFC, dark: 0xA78BFA)
        case .videos:
            return AppTheme.dynamic(light: 0x0891B2, dark: 0x22D3EE)
        case .files:
            return AppTheme.dynamic(light: 0xD97706, dark: 0xFBBF24)
        }
    }
}

enum MeasurementQuality: String, Equatable {
    case verified
    case estimated
    case unavailable
}

struct CategoryUsage: Identifiable, Equatable {
    let category: StorageCategory
    var bytes: Int64
    var quality: MeasurementQuality
    var note: String?

    var id: StorageCategory { category }

    var formattedSize: String {
        StorageFormatter.headline(bytes)
    }

    var statusLabel: String {
        switch quality {
        case .verified:
            return "measured"
        case .estimated:
            return "estimated"
        case .unavailable:
            return "unavailable"
        }
    }
}

struct StorageSnapshot: Equatable {
    var totalCapacity: Int64?
    var usedCapacity: Int64?
    var categories: [CategoryUsage]
    var isLoaded: Bool
    var isPhotoAccessLimited: Bool = false

    static let loading = StorageSnapshot(
        totalCapacity: nil,
        usedCapacity: nil,
        categories: StorageCategory.allCases.map {
            CategoryUsage(category: $0, bytes: 0, quality: .unavailable, note: nil)
        },
        isLoaded: false,
        isPhotoAccessLimited: false
    )

    func usage(for category: StorageCategory) -> CategoryUsage {
        categories.first { $0.category == category }
            ?? CategoryUsage(category: category, bytes: 0, quality: .unavailable, note: nil)
    }

    var measuredBytes: Int64 {
        categories.reduce(0) { total, usage in
            total + (usage.quality == .unavailable ? 0 : usage.bytes)
        }
    }

    /// Free space reported by the device volume. Derived from the same real
    /// capacity values shown in the centre of the chart, never a preset.
    var availableCapacity: Int64? {
        guard let totalCapacity, let usedCapacity else { return nil }
        return max(0, totalCapacity - usedCapacity)
    }

    /// True when the photo library could not be read, either because the
    /// permission was declined, access is restricted, or access is limited.
    var photosAccessNeedsAttention: Bool {
        guard isLoaded else { return false }
        return isPhotoAccessLimited
            || usage(for: .photos).quality == .unavailable
            || usage(for: .videos).quality == .unavailable
    }

    /// The single-line status shown inside the chart. It never presents
    /// partial or unavailable values as verified measurements.
    var statusCaption: String {
        guard isLoaded else { return "Measuring storage…" }

        let unavailable = categories
            .filter { $0.quality == .unavailable }
            .map(\.category)
        let estimated = categories
            .filter { $0.quality == .estimated }
            .map(\.category)

        if unavailable.contains(.photos), unavailable.contains(.videos), estimated.isEmpty {
            return "Photo access is off"
        }

        var parts: [String] = []
        if !estimated.isEmpty {
            parts.append("\(Self.list(estimated)) estimated")
        }
        if !unavailable.isEmpty {
            parts.append("\(Self.list(unavailable)) unavailable")
        }
        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }

        if measuredBytes == 0 {
            return "No tracked media or app files"
        }

        return "Tracked: \(StorageFormatter.headline(measuredBytes))"
    }

    var accessibilitySummary: String {
        guard isLoaded else { return "Measuring storage" }

        return categories.map { usage in
            if usage.quality == .unavailable {
                return "\(usage.category.title) unavailable"
            }
            let suffix = usage.quality == .estimated ? " estimated" : ""
            return "\(usage.category.title) \(usage.formattedSize)\(suffix)"
        }
        .joined(separator: ", ")
    }

    private static func list(_ categories: [StorageCategory]) -> String {
        switch categories.count {
        case 0:
            return ""
        case 1:
            return categories[0].title
        case 2:
            return "\(categories[0].title) and \(categories[1].title)"
        default:
            let head = categories.dropLast().map(\.title).joined(separator: ", ")
            return "\(head), and \(categories.last!.title)"
        }
    }
}

enum StorageFormatter {
    /// Uses whole gigabytes for large values, matching the restrained
    /// typography of the centre label ("113 GB" rather than "113.4 GB").
    static func headline(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }

        let component = components(for: bytes)
        return formatted(component.value, unit: component.unit)
    }

    /// Sub-megabyte values are common in filtered overview categories, where
    /// "0 MB" would hide a real 30 KB item. This keeps small values readable
    /// without changing the Home page's headline formatting.
    static func compact(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }

        if bytes < 1_000_000 {
            let kilobytes = max(1, Int((Double(bytes) / 1_000).rounded()))
            return "\(kilobytes) KB"
        }

        return headline(bytes)
    }

    /// In the rare case that rounding makes the used and total labels equal
    /// (for example "245 GB of 245 GB"), show one truncated decimal for the
    /// used value so the two numbers never read as identical.
    static func usedHeadline(_ used: Int64, total: Int64) -> String {
        let standard = headline(used)
        guard standard == headline(total) else { return standard }

        let component = components(for: used)
        let truncated = (component.value * 10).rounded(.down) / 10
        guard truncated > 0, truncated < component.value else { return standard }

        return "\(oneDecimal(truncated)) \(component.unit)"
    }

    private static func components(for bytes: Int64) -> (value: Double, unit: String) {
        let terabytes = Double(bytes) / 1_000_000_000_000
        if terabytes >= 1 {
            return (terabytes, "TB")
        }

        let gigabytes = Double(bytes) / 1_000_000_000
        if gigabytes >= 1 {
            return (gigabytes, "GB")
        }

        return (Double(bytes) / 1_000_000, "MB")
    }

    private static func formatted(_ value: Double, unit: String) -> String {
        let rounded = value >= 10
            ? value.rounded()
            : (value * 10).rounded() / 10

        if rounded == rounded.rounded() {
            return "\(Int(rounded)) \(unit)"
        }

        return "\(oneDecimal(rounded)) \(unit)"
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
