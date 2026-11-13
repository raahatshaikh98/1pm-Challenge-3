//
//  CleanPlaceholderView.swift
//  1pm Challenge 3
//

import SwiftUI

/// Distinguishes a row chosen from the broom menu from a chart selection while
/// sharing one navigation path. Both currently open the category's overview.
struct CleanCategoryRoute: Hashable {
    let category: StorageCategory
}

/// Placeholder for the broom menu's category rows. Cleaning tools are not
/// built yet, so this only confirms the choice instead of opening the
/// read-only overview chart.
struct CleanPlaceholderView: View {
    let category: StorageCategory

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.12))
                        .frame(width: 96, height: 96)

                    Circle()
                        .stroke(category.color.opacity(0.2), lineWidth: 1)
                        .frame(width: 96, height: 96)

                    Image(systemName: category.symbolName)
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(category.color)
                }

                VStack(spacing: 8) {
                    Text(category.title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("More development coming soon.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityElement(children: .combine)
    }
}
