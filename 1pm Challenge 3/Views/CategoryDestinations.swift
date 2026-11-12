//
//  CategoryDestinations.swift
//  1pm Challenge 3
//

import SwiftUI
import UniformTypeIdentifiers

struct PhotosDetailView: View {
    let usage: CategoryUsage

    var body: some View {
        CategoryDetailView(usage: usage)
    }
}

struct VideosDetailView: View {
    let usage: CategoryUsage

    var body: some View {
        CategoryDetailView(usage: usage)
    }
}

struct FilesDetailView: View {
    let usage: CategoryUsage
    let onLibraryChanged: () async -> Void

    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        CategoryDetailView(usage: usage) {
            isImporting = true
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            importFiles(result)
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
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                importError = error.localizedDescription
            }

        case .success(let urls):
            do {
                let documents = try FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )

                for url in urls {
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess { url.stopAccessingSecurityScopedResource() }
                    }

                    let destination = uniqueDestination(
                        for: url.lastPathComponent,
                        in: documents
                    )
                    try FileManager.default.copyItem(at: url, to: destination)
                }

                Task { await onLibraryChanged() }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func uniqueDestination(for name: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(name)

        guard fileManager.fileExists(atPath: candidate.path) else {
            return candidate
        }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var index = 2

        repeat {
            let filename = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = directory.appendingPathComponent(filename)
            index += 1
        } while fileManager.fileExists(atPath: candidate.path)

        return candidate
    }
}
