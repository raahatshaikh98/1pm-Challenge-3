//
//  HomeTabBar.swift
//  1pm Challenge 3
//

import SwiftUI

/// Two items only: Home and a broom that opens a compact category menu.
/// The bar floats above the content instead of spanning the screen.
struct HomeTabBar: View {
    let onSelectCategory: (StorageCategory) -> Void

    var body: some View {
        HStack(spacing: 0) {
            homeItem
            broomItem
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .adaptiveGlass(in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.hairline, lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 20, x: 0, y: 10)
    }

    private var homeItem: some View {
        VStack(spacing: 3) {
            Image(systemName: "house.fill")
                .font(.system(size: 20, weight: .medium))
            Text("Home")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.primary)
        .frame(width: 92)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Home")
        .accessibilityAddTraits(.isSelected)
    }

    private var broomItem: some View {
        Menu {
            ForEach(StorageCategory.allCases) { category in
                Button {
                    onSelectCategory(category)
                } label: {
                    Label(category.title, systemImage: category.symbolName)
                }
            }
        } label: {
            VStack(spacing: 3) {
                BroomIcon()
                    .frame(width: 22, height: 22)
                Text("Clean")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(AppTheme.secondaryText)
            .frame(width: 92)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .menuOrder(.fixed)
        .accessibilityLabel("Clean")
        .accessibilityHint("Choose photos, videos or files")
    }
}
