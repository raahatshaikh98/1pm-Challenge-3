//
//  ItemSelectionView.swift
//  1pm Challenge 3
//

import Photos
import SwiftUI
import UIKit


struct ItemSelectionView: View {
    let category: OverviewCategory
    let items: [OverviewItem]
    var onDeleted: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedIDs: Set<String> = []
    @State private var deletedIDs: Set<String> = []
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var visibleItems: [OverviewItem] {
        items
            .filter { !deletedIDs.contains($0.id) }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private var selectedItems: [OverviewItem] {
        visibleItems.filter { selectedIDs.contains($0.id) }
    }

    private var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.bytes }
    }

    private var isAllSelected: Bool {
        !visibleItems.isEmpty && selectedIDs.count == visibleItems.count
    }

    private let destructiveColor = Color(hex: 0xDC2626)

    var body: some View {
        ZStack {
            AppBackground()

            if visibleItems.isEmpty {
                finishedState
            } else {
                itemList

                if isDeleting {
                    deletingOverlay
                }
            }
        }
        .navigationTitle("Select \(category.kind.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(deleteActionTitle, role: .destructive) {
                Task { await deleteSelectedItems() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected items from your iPhone. Photos and videos stay in Recently Deleted for 30 days.")
        }
        .alert(
            "Couldn’t delete items",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - List

    private var itemList: some View {
        ScrollView {
            VStack(spacing: 0) {
                selectionHeader
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                LazyVStack(spacing: 0) {
                    ForEach(visibleItems) { item in
                        itemRow(item)

                        if item.id != visibleItems.last?.id {
                            Rectangle()
                                .fill(AppTheme.hairline)
                                .frame(height: 0.5)
                                .padding(.leading, 58)
                        }
                    }
                }

                Text(category.kind == .files
                     ? "Deleted files can’t be recovered."
                     : "Deleted photos and videos stay in Recently Deleted for 30 days.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .safeAreaInset(edge: .bottom) {
            deleteBar
        }
        .allowsHitTesting(!isDeleting)
    }

    private var selectionHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedIDs.isEmpty ? "Select items to delete" : selectedSummary)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(selectedIDs.isEmpty
                     ? "Tap an item to add it to your selection."
                     : "\(StorageFormatter.compact(selectedBytes)) selected")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 0)

            Button {
                toggleSelectAll()
            } label: {
                Text(isAllSelected ? "Deselect All" : "Select All")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.surface)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
        )
    }

    private var selectedSummary: String {
        let count = selectedIDs.count
        return count == 1 ? "1 item selected" : "\(count) items selected"
    }

    private func itemRow(_ item: OverviewItem) -> some View {
        let isSelected = selectedIDs.contains(item.id)

        return Button {
            toggleSelection(item)
        } label: {
            HStack(spacing: 12) {
                OverviewItemThumbnail(
                    item: item,
                    tint: category.color
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

                Spacer(minLength: 8)

                selectionIndicator(isSelected: isSelected)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.formattedSize)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? category.color : .clear)
                .frame(width: 22, height: 22)

            Circle()
                .strokeBorder(
                    isSelected ? category.color : Color.primary.opacity(0.18),
                    lineWidth: 1.5
                )
                .frame(width: 22, height: 22)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityHidden(true)
    }

    // MARK: - Delete bar

    private var deleteBar: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(deleteButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(selectedIDs.isEmpty ? AppTheme.secondaryText : Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedIDs.isEmpty ? AppTheme.surface : destructiveColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedIDs.isEmpty || isDeleting)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.hairline)
                .frame(height: 0.5)
        }
        .accessibilityLabel(deleteButtonTitle)
        .accessibilityHint("Deletes the selected items")
    }

    private var deleteButtonTitle: String {
        if isDeleting { return "Deleting…" }
        guard !selectedIDs.isEmpty else { return "Select items to delete" }

        let count = selectedIDs.count
        let size = StorageFormatter.compact(selectedBytes)
        return "Delete \(count) \(count == 1 ? "item" : "items") · \(size)"
    }

    private var deleteConfirmationTitle: String {
        let count = selectedIDs.count
        return count == 1 ? "Delete 1 item?" : "Delete \(count) items?"
    }

    private var deleteActionTitle: String {
        let count = selectedIDs.count
        return "Delete \(count) \(count == 1 ? "Item" : "Items")"
    }

    // MARK: - Finished state

    private var finishedState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(successColor.opacity(0.12))
                    .frame(width: 88, height: 88)

                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(successColor)
            }

            Text("All clean")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(finishedMessage)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 290)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 11)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var finishedMessage: String {
        guard !deletedIDs.isEmpty else {
            return "There are no items left to delete in this category."
        }

        let count = deletedIDs.count
        return count == 1
            ? "1 item deleted. Your storage totals will update when you go back."
            : "\(count) items deleted. Your storage totals will update when you go back."
    }

    private var successColor: Color {
        AppTheme.dynamic(light: 0x10B981, dark: 0x6EE7B7)
    }

    private var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.secondaryText)

                Text("Deleting…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func toggleSelection(_ item: OverviewItem) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedIDs.contains(item.id) {
                selectedIDs.remove(item.id)
            } else {
                selectedIDs.insert(item.id)
            }
        }
    }

    private func toggleSelectAll() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isAllSelected {
                selectedIDs.removeAll()
            } else {
                selectedIDs = Set(visibleItems.map(\.id))
            }
        }
    }

    @MainActor
    private func deleteSelectedItems() async {
        guard !selectedIDs.isEmpty, !isDeleting else { return }

        isDeleting = true
        defer { isDeleting = false }

        let outcome = await ItemDeletion.delete(selectedItems)

        deletedIDs.formUnion(outcome.deletedIDs)
        selectedIDs.subtract(outcome.deletedIDs)

        if !outcome.deletedIDs.isEmpty {
            await onDeleted()
        }

        if let message = outcome.message {
            errorMessage = message
        }
    }
}

// MARK: - Deletion

private enum ItemDeletion {
    struct Outcome {
        var deletedIDs: Set<String>
        var message: String?
    }

    static func delete(_ items: [OverviewItem]) async -> Outcome {
        var deletedIDs = Set<String>()
        var message: String?

        let assetItems = items.filter { $0.assetIdentifier != nil }
        if !assetItems.isEmpty {
            do {
                try await deleteAssets(assetItems)
                deletedIDs.formUnion(assetItems.map(\.id))
            } catch {
                message = error.localizedDescription
            }
        }

        for item in items where item.fileURL != nil {
            guard let url = item.fileURL else { continue }

            do {
                try FileManager.default.removeItem(at: url)
                deletedIDs.insert(item.id)
            } catch {
                message = message ?? "Some files couldn’t be deleted."
            }
        }

        return Outcome(deletedIDs: deletedIDs, message: message)
    }

    private static func deleteAssets(_ items: [OverviewItem]) async throws {
        let identifiers = items.compactMap(\.assetIdentifier)
        guard !identifiers.isEmpty else { return }

        let fetch = PHAsset.fetchAssets(
            withLocalIdentifiers: identifiers,
            options: nil
        )

        var assets: [PHAsset] = []
        assets.reserveCapacity(fetch.count)
        fetch.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        guard !assets.isEmpty else { return }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: error ?? ItemDeletionError.photoLibrary
                    )
                }
            }
        }
    }
}

private enum ItemDeletionError: LocalizedError {
    case photoLibrary

    var errorDescription: String? {
        "The selected photos and videos weren’t deleted."
    }
}

#Preview {
    NavigationStack {
        ItemSelectionView(
            category: .largePhotos,
            items: (1...8).map { index in
                OverviewItem(
                    id: "preview-\(index)",
                    name: "IMG_00\(index).HEIC",
                    bytes: Int64(index) * 2_400_000,
                    date: Date().addingTimeInterval(-Double(index) * 86_400),
                    assetIdentifier: nil,
                    fileURL: nil,
                    isVideo: false
                )
            },
            onDeleted: {}
        )
    }
}
