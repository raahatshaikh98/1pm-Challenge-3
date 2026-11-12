//
//  OverviewPage.swift
//  1pm Challenge 3
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Shared layout for Photos, Videos and Files. Only the data source and the
/// category list differ, so all three pages keep identical spacing, chart
/// styling and navigation behaviour.
struct OverviewPage: View {
    let kind: StorageCategory
    var onLibraryChanged: (() async -> Void)?

    @StateObject private var viewModel: OverviewViewModel
    @State private var showFilters = false
    @State private var detailCategory: OverviewCategory?
    @State private var isImporting = false
    @State private var importError: String?

    init(
        kind: StorageCategory,
        onLibraryChanged: (() async -> Void)? = nil
    ) {
        self.kind = kind
        self.onLibraryChanged = onLibraryChanged
        _viewModel = StateObject(wrappedValue: OverviewViewModel(kind: kind))
    }

    var body: some View {
        ZStack {
            AppBackground()

            GeometryReader { proxy in
                let diameter = chartDiameter(for: proxy.size)

                Group {
                    if viewModel.needsPhotoPermission {
                        permissionState
                    } else if viewModel.isEmptyState {
                        emptyState
                    } else {
                        content(diameter: diameter)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: viewModel.isFilterActive
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(.system(size: 17, weight: .semibold))
                }
                .tint(.primary)
                .accessibilityLabel("Filter \(kind.title)")
            }
        }
        .sheet(isPresented: $showFilters) {
            OverviewFilterSheet(
                kind: kind,
                usages: viewModel.usages,
                initialSelection: viewModel.appliedFilters,
                initialThreshold: viewModel.outdatedThreshold
            ) { selection, threshold in
                viewModel.applyFilters(selection)
                viewModel.applyOutdatedThreshold(threshold)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $detailCategory) { category in
            OverviewCategoryDetailView(
                kind: kind,
                usage: viewModel.usage(for: category)
            )
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert(
            "Couldn’t add files",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .task {
            viewModel.scanIfNeeded()
        }
        .onDisappear {
            viewModel.cancelScan()
        }
    }

    // MARK: - Main state

    private func content(diameter: CGFloat) -> some View {
        VStack(spacing: 0) {
            OverviewLegendView(usages: viewModel.displayedUsages) { category in
                detailCategory = category
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)

            Spacer(minLength: 12)

            OverviewDonutChartView(
                kind: kind,
                usages: viewModel.displayedUsages,
                totalBytes: viewModel.displayedBytes,
                filterSummary: viewModel.filterSummary,
                diameter: diameter
            ) { category in
                detailCategory = category
            }

            if kind == .files {
                addFilesButton
                    .padding(.top, 16)
            }

            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.secondaryText)
                    .padding(.top, 12)
            }

            if viewModel.accessState.isLimited {
                limitedAccessNote
                    .padding(.top, 14)
            }

            if viewModel.skippedItems > 0 {
                skippedItemsNote
                    .padding(.top, 7)
            }

            Spacer(minLength: 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(kind.color.opacity(0.1))
                    .frame(width: 88, height: 88)

                Image(systemName: emptyStateSymbol)
                    .font(.system(size: 31, weight: .medium))
                    .foregroundStyle(kind.color)
            }

            Text(viewModel.emptyTitle)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(viewModel.emptyMessage)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 290)

            if kind == .files {
                addFilesButton
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateSymbol: String {
        if viewModel.selectedCategories.count == 1,
           let category = viewModel.selectedCategories.first {
            return category.symbolName
        }
        return kind.symbolName
    }

    private var permissionState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(kind.color.opacity(0.1))
                    .frame(width: 88, height: 88)

                Image(systemName: "lock.fill")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(kind.color)
            }

            Text("Photo access is off")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(permissionMessage)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 300)

            Button(action: handlePermissionAction) {
                HStack(spacing: 6) {
                    Text(viewModel.accessState == .notDetermined
                         ? "Allow photo access"
                         : "Open Settings")
                    Image(systemName: viewModel.accessState == .notDetermined
                          ? "photo.badge.plus"
                          : "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionMessage: String {
        if viewModel.accessState == .notDetermined {
            return "Allow full access to measure your photos and videos. Choose “Allow Full Access” on the next screen."
        }
        return "Allow full access in Settings so this page can measure the library. Only the items you allow are included."
    }

    // MARK: - Small actions and notes

    private var addFilesButton: some View {
        Button {
            isImporting = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                Text("Add files from On My iPhone")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary)
            )
        }
        .buttonStyle(.plain)
    }

    private var limitedAccessNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 11, weight: .semibold))

            Text("Limited access — only allowed items are shown.")
                .font(.system(size: 11.5, weight: .medium))

            Button("Manage") {
                openSettings()
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Color.primary)
        }
        .foregroundStyle(AppTheme.secondaryText)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.surface)
        )
    }

    private var skippedItemsNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 10, weight: .semibold))
            Text("\(viewModel.skippedItems) items couldn’t be read.")
                .font(.system(size: 11, weight: .regular))
        }
        .foregroundStyle(AppTheme.tertiaryText)
    }

    // MARK: - Actions

    private func handlePermissionAction() {
        if viewModel.accessState == .notDetermined {
            Task {
                await viewModel.requestPhotoAccessAndScan()
            }
        } else {
            openSettings()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                importError = error.localizedDescription
            }

        case .success(let urls):
            do {
                try DocumentLibrary.copyImportedFiles(from: urls)
                Task {
                    await onLibraryChanged?()
                    viewModel.rescan()
                }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func chartDiameter(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 260 }

        let widthLimit = size.width - 56
        let heightLimit = size.height * 0.48
        return min(widthLimit, heightLimit, 340)
    }
}
