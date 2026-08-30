//
//  CursorScanner.swift
//  Again Cleaner
//
//  Cursor (and VS Code-like apps) store both throwaway caches AND real user
//  data under one Application Support folder. This scanner shows the internal
//  breakdown so caches are safe to clear while WebStorage / globalStorage /
//  workspaceStorage stay Review Required — never "Delete Cursor Data".
//

import Foundation

nonisolated struct CursorScanner: CleanupScanner {
    let id = "cursor"
    let displayName = "Cursor Storage"

    // Subpaths that are pure cache (regeneratable) vs. real data (review).
    private nonisolated static let safeSub: [String] = [
        "Cache", "CachedData", "GPUCache", "Code Cache", "DawnWebGPUCache",
        "DawnGraphiteCache", "ShaderCache", "CachedProfilesData", "logs", "Crashpad",
    ]
    private nonisolated static let reviewSub: [String] = [
        "WebStorage", "Local Storage", "Session Storage", "IndexedDB",
        "Service Worker", "User/globalStorage", "User/workspaceStorage", "User/History",
    ]

    private nonisolated static func root() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor")
    }

    nonisolated var ownedPrefixes: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [Self.root(), home.appendingPathComponent(".cursor")]
    }

    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: Self.root().path)
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let root = Self.root()
        var out: [CleanupCandidate] = []

        for sub in Self.safeSub {
            if let c = await candidate(root.appendingPathComponent(sub), risk: .regeneratable,
                explanation: String(localized: "Cursor cache — rebuilt automatically."),
                consequence: String(localized: "Removed; Cursor regenerates it on next launch."),
                ctx: ctx) { out.append(c) }
        }
        for sub in Self.reviewSub {
            if let c = await candidate(root.appendingPathComponent(sub), risk: .reviewRequired,
                explanation: String(localized: "Cursor user data (storage/history). May hold settings, chat history or unsynced state."),
                consequence: String(localized: "Review before removing — this is not cache."),
                ctx: ctx) { out.append(c) }
        }
        return out
    }

    private func candidate(_ url: URL, risk: CleanupRisk, explanation: String,
                           consequence: String, ctx: ScanContext) async -> CleanupCandidate? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = await ctx.usage.size(of: url, isCancelled: ctx.isCancelled)
        guard size > 0 else { return nil }
        return CleanupCandidate(
            scannerID: "cursor:\(url.lastPathComponent)",
            name: "Cursor / \(url.lastPathComponent)",
            path: url, size: size, risk: risk,
            explanation: explanation, consequence: consequence,
            lastModified: try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
            method: .filesystem
        )
    }
}
