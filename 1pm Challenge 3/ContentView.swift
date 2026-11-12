//
//  ContentView.swift
//  1pm Challenge 3
//

import SwiftUI
import Photos
import UIKit

struct ContentView: View {
    @StateObject private var store = StorageStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    @State private var showPhotoAccessExplanation = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                snapshot: store.snapshot,
                onSelectCategory: { category in
                    path.append(category)
                },
                onSelectCleanCategory: { category in
                    path.append(CleanCategoryRoute(category: category))
                },
                onRequestPhotoAccess: handlePhotoAccessRequest
            )
            .navigationDestination(for: StorageCategory.self) { category in
                destination(for: category)
            }
            .navigationDestination(for: CleanCategoryRoute.self) { route in
                CleanPlaceholderView(category: route.category)
            }
        }
        .tint(AppTheme.accent)
        .task {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            await store.refresh(requestAccess: false)

            if status == .notDetermined {
                showPhotoAccessExplanation = true
            }
        }
        .alert("Allow full photo access?", isPresented: $showPhotoAccessExplanation) {
            Button("Continue") {
                Task { await store.requestPhotoAccess() }
            }
            Button("Not Now", role: .cancel) {
                Task { await store.refresh(requestAccess: false) }
            }
        } message: {
            Text("Choose “Allow Full Access” on the next screen so the donut can measure all of your photos and videos.")
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.refreshIfNeeded() }
        }
    }

    @ViewBuilder
    private func destination(for category: StorageCategory) -> some View {
        switch category {
        case .photos:
            OverviewPage(kind: .photos)
        case .videos:
            OverviewPage(kind: .videos)
        case .files:
            OverviewPage(kind: .files) {
                await store.refresh()
            }
        }
    }

    private func handlePhotoAccessRequest() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if status == .notDetermined {
            Task { await store.requestPhotoAccess() }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}

@main
struct Challenge3App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
