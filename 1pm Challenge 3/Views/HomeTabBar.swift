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

/// SF Symbols has no broom glyph, so this small vector keeps the tab bar
/// faithful to the brief without adding an asset dependency.
private struct BroomIcon: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 12, y: 2.6))
                path.addLine(to: CGPoint(x: 12, y: 11.4))
            }
            .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            Path { path in
                path.move(to: CGPoint(x: 7.9, y: 11.0))
                path.addLine(to: CGPoint(x: 16.1, y: 11.0))
                path.addLine(to: CGPoint(x: 18.3, y: 18.6))
                path.addQuadCurve(
                    to: CGPoint(x: 17.1, y: 19.9),
                    control: CGPoint(x: 18.3, y: 19.9)
                )
                path.addLine(to: CGPoint(x: 6.9, y: 19.9))
                path.addQuadCurve(
                    to: CGPoint(x: 5.7, y: 18.6),
                    control: CGPoint(x: 5.7, y: 19.9)
                )
                path.closeSubpath()
            }
            .fill()

            Path { path in
                let starts: [CGFloat] = [7.3, 10.1, 13.9, 16.7]
                let ends: [CGFloat] = [6.8, 9.7, 14.3, 17.2]
                for index in starts.indices {
                    path.move(to: CGPoint(x: starts[index], y: 19.4))
                    path.addLine(to: CGPoint(x: ends[index], y: 21.5))
                }
            }
            .stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        .frame(width: 24, height: 24)
    }
}
