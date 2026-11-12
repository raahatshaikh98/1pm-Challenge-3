//
//  OverviewLegendView.swift
//  1pm Challenge 3
//

import SwiftUI

/// Two-column legend for the overview pages. It only receives the categories
/// that are actually drawn, so the key always matches the chart.
struct OverviewLegendView: View {
    let usages: [OverviewUsage]
    let onSelect: (OverviewCategory) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(usages) { usage in
                Button {
                    onSelect(usage.category)
                } label: {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(usage.category.color)
                            .frame(width: 8, height: 8)

                        Text(usage.category.shortTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.82))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text(usage.formattedSize)
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.tertiaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.surface)
                    )
                    .contentShape(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(usage.category.title), \(usage.formattedSize)"
                )
                .accessibilityHint("Opens the item list")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
