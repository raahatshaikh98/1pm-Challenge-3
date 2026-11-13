//
//  ItemFilterSheet.swift
//  1pm Challenge 3
//

import SwiftUI

/// Filters available on the item selection page. Each one narrows the
/// current list, so an item has to match every selected filter.
enum ItemFilter: String, CaseIterable, Identifiable {
    case screenshots
    case duplicates
    case blurry
    case old
    case recents
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshots:
            return "Screenshots"
        case .duplicates:
            return "Duplicates"
        case .blurry:
            return "Blurry"
        case .old:
            return "Old"
        case .recents:
            return "Recents"
        case .large:
            return "Large"
        }
    }

    var symbolName: String {
        switch self {
        case .screenshots:
            return "camera.viewfinder"
        case .duplicates:
            return "square.on.square"
        case .blurry:
            return "camera.filters"
        case .old:
            return "clock.arrow.circlepath"
        case .recents:
            return "clock"
        case .large:
            return "arrow.up.right"
        }
    }

    func matches(_ item: OverviewItem, kind: StorageCategory) -> Bool {
        switch self {
        case .screenshots:
            return item.isScreenshot
        case .duplicates:
            return item.isDuplicate
        case .blurry:
            return item.isBlurry
        case .old:
            guard let date = item.date else { return false }
            return date < ItemFilter.oldCutoff
        case .recents:
            guard let date = item.date else { return false }
            return date >= ItemFilter.recentsCutoff
        case .large:
            return item.bytes >= OverviewCategory.largeThreshold(for: kind)
        }
    }

    private static var oldCutoff: Date {
        Calendar.current.date(byAdding: .month, value: -6, to: Date())
            ?? Date().addingTimeInterval(-180 * 24 * 60 * 60)
    }

    private static var recentsCutoff: Date {
        Date().addingTimeInterval(-30 * 24 * 60 * 60)
    }
}

/// Bottom-sheet filter picker for the item selection list. It mirrors the
/// Overview filter sheet so both filter entry points feel the same.
struct ItemFilterSheet: View {
    let items: [OverviewItem]
    let kind: StorageCategory
    let initialSelection: Set<ItemFilter>
    let onApply: (Set<ItemFilter>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<ItemFilter>

    private var allFilters: [ItemFilter] {
        ItemFilter.allCases
    }

    init(
        items: [OverviewItem],
        kind: StorageCategory,
        initialSelection: Set<ItemFilter>,
        onApply: @escaping (Set<ItemFilter>) -> Void
    ) {
        self.items = items
        self.kind = kind
        self.initialSelection = initialSelection
        self.onApply = onApply
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                selectionControls

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(allFilters) { filter in
                            filterRow(filter)

                            if filter != allFilters.last {
                                Rectangle()
                                    .fill(AppTheme.hairline)
                                    .frame(height: 0.5)
                                    .padding(.leading, 34)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            .background(
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                applyBar
            }
        }
    }

    private var selectionControls: some View {
        HStack(spacing: 16) {
            Button("Select All") {
                selection = Set(allFilters)
            }
            .disabled(selection.count == allFilters.count)

            Spacer()

            Button("Clear All") {
                selection.removeAll()
            }
            .disabled(selection.isEmpty)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(AppTheme.secondaryText)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func filterRow(_ filter: ItemFilter) -> some View {
        let isSelected = selection.contains(filter)
        let count = items.filter { filter.matches($0, kind: kind) }.count

        return Button {
            if isSelected {
                selection.remove(filter)
            } else {
                selection.insert(filter)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: filter.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected
                                     ? kind.color
                                     : AppTheme.tertiaryText)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(filter.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subtitle(for: count))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(
                        isSelected
                            ? kind.color
                            : Color.primary.opacity(0.16)
                    )
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func subtitle(for count: Int) -> String {
        switch count {
        case 0:
            return "No items"
        case 1:
            return "1 item"
        default:
            return "\(count) items"
        }
    }

    private var applyBar: some View {
        VStack(spacing: 10) {
            Text(selection.isEmpty
                 ? "No filters selected — all items will be shown."
                 : "\(selection.count) of \(allFilters.count) filters selected.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center)

            Button {
                onApply(selection)
                dismiss()
            } label: {
                Text("Apply")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .label))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(
            Color(uiColor: .systemGroupedBackground)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppTheme.hairline)
                        .frame(height: 0.5)
                }
        )
    }
}

#Preview {
    ItemFilterSheet(
        items: (1...8).map { index in
            OverviewItem(
                id: "preview-\(index)",
                name: "IMG_00\(index).HEIC",
                bytes: Int64(index) * 2_400_000,
                date: Date().addingTimeInterval(-Double(index) * 30 * 86_400),
                assetIdentifier: nil,
                fileURL: nil,
                isVideo: false,
                isScreenshot: index.isMultiple(of: 3),
                isBlurry: index.isMultiple(of: 4),
                isDuplicate: index.isMultiple(of: 5)
            )
        },
        kind: .photos,
        initialSelection: [.large, .recents],
        onApply: { _ in }
    )
}
