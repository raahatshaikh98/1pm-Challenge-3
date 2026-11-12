//
//  OverviewFilterSheet.swift
//  1pm Challenge 3
//

import SwiftUI

/// Native-looking category filter. An empty selection is intentionally the
/// same as "show everything", matching the brief's Clear All behaviour.
struct OverviewFilterSheet: View {
    let kind: StorageCategory
    let usages: [OverviewUsage]
    let initialSelection: Set<OverviewCategory>
    let initialThreshold: OutdatedThreshold
    let onApply: (Set<OverviewCategory>, OutdatedThreshold) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<OverviewCategory>
    @State private var threshold: OutdatedThreshold

    init(
        kind: StorageCategory,
        usages: [OverviewUsage],
        initialSelection: Set<OverviewCategory>,
        initialThreshold: OutdatedThreshold,
        onApply: @escaping (Set<OverviewCategory>, OutdatedThreshold) -> Void
    ) {
        self.kind = kind
        self.usages = usages
        self.initialSelection = initialSelection
        self.initialThreshold = initialThreshold
        self.onApply = onApply
        _selection = State(initialValue: initialSelection)
        _threshold = State(initialValue: initialThreshold)
    }

    private var categories: [OverviewCategory] {
        OverviewCategory.categories(for: kind)
    }

    private var outdatedCategory: OverviewCategory {
        OverviewCategory.outdatedCategory(for: kind)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                selectionControls

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(categories) { category in
                            categoryRow(category)

                            if category == outdatedCategory,
                               selection.contains(category) {
                                thresholdRow
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            if category != categories.last {
                                Rectangle()
                                    .fill(AppTheme.hairline)
                                    .frame(height: 0.5)
                                    .padding(.leading, 34)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .animation(.easeInOut(duration: 0.2), value: selection)
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

    // MARK: - Controls

    private var selectionControls: some View {
        HStack(spacing: 16) {
            Button("Select All") {
                selection = Set(categories)
            }
            .disabled(selection.count == categories.count)

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

    private func categoryRow(_ category: OverviewCategory) -> some View {
        let usage = usage(for: category)
        let isSelected = selection.contains(category)

        return Button {
            if isSelected {
                selection.remove(category)
            } else {
                selection.insert(category)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(category.color)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subtitle(for: usage))
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

    /// Only `Files` (and the matching Photos/Videos equivalent) can be
    /// outdated, so the age chooser appears right under that row once it is
    /// selected. Changing it only reclassifies the existing scan.
    private var thresholdRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(width: 22)

            Text("Older than")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 8)

            Picker("Older than", selection: $threshold) {
                ForEach(OutdatedThreshold.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.menu)
            .tint(kind.color)
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(.leading, 34)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Outdated means older than \(threshold.title)")
    }

    private var applyBar: some View {
        VStack(spacing: 10) {
            Text(selection.isEmpty
                 ? "No categories selected — all categories will be shown."
                 : "\(selection.count) of \(categories.count) selected.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center)

            Button {
                onApply(selection, threshold)
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

    private func usage(for category: OverviewCategory) -> OverviewUsage {
        usages.first { $0.category == category }
            ?? OverviewUsage(category: category, bytes: 0, items: [])
    }

    private func subtitle(for usage: OverviewUsage) -> String {
        guard usage.itemCount > 0 else { return "No items" }
        let items = usage.itemCount == 1 ? "1 item" : "\(usage.itemCount) items"
        return "\(items) · \(usage.formattedSize)"
    }
}
