//
//  DocumentLibrary.swift
//  1pm Challenge 3
//

import Foundation

/// The app's visible "On My iPhone" folder. Everything here is already inside
/// the app sandbox, so no security-scoped bookmark is needed to read it.
enum DocumentLibrary {
    static func documentsDirectory() throws -> URL {
        try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    static func copyImportedFiles(from urls: [URL]) throws {
        let documents = try documentsDirectory()

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
    }

    static func uniqueDestination(for name: String, in directory: URL) -> URL {
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
