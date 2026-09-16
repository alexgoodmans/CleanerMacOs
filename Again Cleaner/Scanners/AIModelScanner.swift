//
//  AIModelScanner.swift
//  Again Cleaner
//
//  Finds local ML weights. These are never junk and never auto-deleted.
//

import Foundation

nonisolated struct AIModelScanner: CleanupScanner {
    let id = "aimodel"
    let displayName = "Local AI Models"

    private static let minSize: Int64 = 50_000_000

    private static func searchRoots() -> [URL] {
        let home = DirListing.home
        return [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent(".cache"),
            home.appendingPathComponent(".ollama"),
            home.appendingPathComponent("Library/Caches"),
        ]
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        var seen: Set<String> = []
        for root in Self.searchRoots() {
            if ctx.isCancelled() { break }
            guard DirListing.exists(root) else { continue }
            out += await walk(root, depth: 0, maxDepth: 8, ctx: ctx, seen: &seen)
        }
        return out
    }

    private func walk(
        _ dir: URL, depth: Int, maxDepth: Int,
        ctx: ScanContext, seen: inout Set<String>
    ) async -> [CleanupCandidate] {
        if depth > maxDepth || ctx.isCancelled() { return [] }
        var out: [CleanupCandidate] = []
        let children = DirListing.children(of: dir, skipHidden: false)
        let names = children.map(\.lastPathComponent)

        if AIModelDetection.isModelDirectory(name: dir.lastPathComponent, childNames: names) {
            let key = PathGuard.canonicalPath(dir)
            if !seen.contains(key), let size = await ctx.measured(dir), size >= Self.minSize {
                seen.insert(key)
                let app = dir.pathComponents.dropLast().last
                let info = AIModelDetection.explanation(app: app, modelName: dir.lastPathComponent)
                out.append(CleanupCandidate(
                    scannerID: "aimodel:\(dir.lastPathComponent)",
                    name: dir.lastPathComponent,
                    path: dir, size: size,
                    risk: .reviewRequired,
                    category: .localAIModels,
                    developer: app,
                    confidence: .high,
                    isRegenerable: false,
                    explanation: info.why,
                    consequence: info.consequence,
                    lastModified: DirListing.modified(dir)
                ))
                return out
            }
        }

        for child in children {
            if ctx.isCancelled() { break }
            if AIModelDetection.isModelFile(child) {
                let key = PathGuard.canonicalPath(child)
                if seen.contains(key) { continue }
                guard let size = await ctx.measured(child), size >= Self.minSize else { continue }
                seen.insert(key)
                let info = AIModelDetection.explanation(
                    app: dir.lastPathComponent, modelName: child.lastPathComponent)
                out.append(CleanupCandidate(
                    scannerID: "aimodel:\(child.lastPathComponent)",
                    name: child.lastPathComponent,
                    path: child, size: size,
                    risk: .reviewRequired,
                    category: .localAIModels,
                    developer: dir.lastPathComponent,
                    confidence: .high,
                    isRegenerable: false,
                    explanation: info.why,
                    consequence: info.consequence,
                    lastModified: DirListing.modified(child)
                ))
            } else if (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                out += await walk(child, depth: depth + 1, maxDepth: maxDepth, ctx: ctx, seen: &seen)
            }
        }
        return out
    }
}
