//
//  StorageLegendView.swift
//  1pm Challenge 3
//

import SwiftUI

/// The compact colour key for the donut. Unavailable categories keep their
/// colour but use a hollow dot and dimmed label so they are never mistaken
/// for a verified measurement. Each entry also shows the measured size, so an
/// empty Files folder still reads as "0 MB" instead of silently vanishing.
struct StorageLegendView: View {
    let usages: [CategoryUsage]
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(usages) { usage in
                VStack(spacing: 3) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(isUnavailable(usage) && !isLoading ? Color.clear : usage.category.color)
                            .frame(width: 8, height: 8)
                            .overlay {
                                Circle()
                                    .stroke(
                                        usage.category.color.opacity(isUnavailable(usage) && !isLoading ? 0.9 : 0),
                                        lineWidth: 1.2
                                    )
                            }
                            .opacity(isLoading ? 0.45 : 1)

                        Text(usage.category.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(labelColor(for: usage))
                            .lineLimit(1)
                    }
                    .fixedSize()

                    Text(sizeText(for: usage))
                        .font(.system(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: usage))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func sizeText(for usage: CategoryUsage) -> String {
        if isLoading { return "measuring" }
        if isUnavailable(usage) { return "unavailable" }
        return usage.formattedSize
    }

    private func accessibilityLabel(for usage: CategoryUsage) -> String {
        if isLoading {
            return "\(usage.category.title), measuring"
        }
        if isUnavailable(usage) {
            return "\(usage.category.title), unavailable"
        }
        let suffix = usage.quality == .estimated ? " estimated" : ""
        return "\(usage.category.title), \(usage.formattedSize)\(suffix)"
    }

    private func isUnavailable(_ usage: CategoryUsage) -> Bool {
        usage.quality == .unavailable
    }

    private func labelColor(for usage: CategoryUsage) -> Color {
        if isLoading {
            return Color.primary.opacity(0.45)
        }
        return isUnavailable(usage)
            ? Color.primary.opacity(0.38)
            : Color.primary.opacity(0.82)
    }
}
