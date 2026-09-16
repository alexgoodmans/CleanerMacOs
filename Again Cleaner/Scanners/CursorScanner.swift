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

    private struct Bucket {
        let rel: String
        let risk: CleanupRisk
        let why: String
        let consequence: String
        let developer: String
    }

    private static func root() -> URL {
        DirListing.home.appendingPathComponent("Library/Application Support/Cursor")
    }

    var ownedPrefixes: [URL] {
        [
            Self.root(),
            DirListing.home.appendingPathComponent("Library/Application Support/Code"),
            DirListing.home.appendingPathComponent(".cursor/logs"),
        ]
    }

    func isAvailable() -> Bool {
        DirListing.exists(Self.root())
            || DirListing.exists(DirListing.home.appendingPathComponent("Library/Application Support/Code"))
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        out += await scanApp("Cursor", root: Self.root(), ctx: ctx)
        out += await scanApp(
            "VS Code",
            root: DirListing.home.appendingPathComponent("Library/Application Support/Code"),
            ctx: ctx
        )
        if let c = await ctx.candidate(
            scannerID: "cursor:dot-logs",
            name: String(localized: "Cursor logs (~/.cursor)"),
            url: DirListing.home.appendingPathComponent(".cursor/logs"),
            risk: .safe,
            explanation: String(localized: "Cursor log files in ~/.cursor/logs."),
            consequence: String(localized: "Removed. Cursor writes new logs as needed."),
            category: .cursorIDE, developer: "Cursor"
        ) { out.append(c) }
        return out
    }

    private func scanApp(_ app: String, root: URL, ctx: ScanContext) async -> [CleanupCandidate] {
        guard DirListing.exists(root) else { return [] }
        let buckets: [Bucket] = [
            .init(rel: "Cache", risk: .usuallySafe,
                  why: String(localized: "\(app) HTTP/disk cache — rebuilt automatically."),
                  consequence: String(localized: "Removed; \(app) regenerates it on next launch."),
                  developer: app),
            .init(rel: "CachedData", risk: .usuallySafe,
                  why: String(localized: "\(app) V8 cached data."),
                  consequence: String(localized: "Regenerated on next launch."),
                  developer: app),
            .init(rel: "GPUCache", risk: .usuallySafe,
                  why: String(localized: "\(app) GPU cache."),
                  consequence: String(localized: "Regenerated on next launch."),
                  developer: app),
            .init(rel: "Code Cache", risk: .usuallySafe,
                  why: String(localized: "\(app) code cache."),
                  consequence: String(localized: "Regenerated on next launch."),
                  developer: app),
            .init(rel: "DawnWebGPUCache", risk: .usuallySafe,
                  why: String(localized: "\(app) WebGPU cache."),
                  consequence: String(localized: "Regenerated on next launch."),
                  developer: app),
            .init(rel: "logs", risk: .safe,
                  why: String(localized: "\(app) logs."),
                  consequence: String(localized: "Removed."),
                  developer: app),
            .init(rel: "Crashpad", risk: .safe,
                  why: String(localized: "\(app) crash dumps."),
                  consequence: String(localized: "Removed."),
                  developer: app),
            .init(rel: "CachedExtensionVSIXs/.trash", risk: .safe,
                  why: String(localized: "\(app) discarded extension installers. High-confidence cleanup — this is a trash folder for .vsix files."),
                  consequence: String(localized: "Removed. Current extensions keep working."),
                  developer: app),
            .init(rel: "CachedExtensionVSIXs", risk: .usuallySafe,
                  why: String(localized: "\(app) cached extension installers (.vsix). They can be re-downloaded."),
                  consequence: String(localized: "The next extension install re-downloads the package."),
                  developer: app),
            .init(rel: "WebStorage", risk: .reviewRequired,
                  why: String(localized: "\(app) WebStorage can hold extension state, sessions or persistent web data. This is not cache."),
                  consequence: String(localized: "Review before removing — you may lose unsynced state."),
                  developer: app),
            .init(rel: "User/globalStorage", risk: .reviewRequired,
                  why: String(localized: "\(app) globalStorage holds extension databases, indexes and history. Not cache."),
                  consequence: String(localized: "Review. Individual extension folders inside can be large."),
                  developer: app),
            .init(rel: "User/workspaceStorage", risk: .reviewRequired,
                  why: String(localized: "\(app) workspaceStorage is per-workspace state. Not cache."),
                  consequence: String(localized: "Review before removing."),
                  developer: app),
            .init(rel: "blob_storage", risk: .reviewRequired,
                  why: String(localized: "\(app) blob_storage is Chromium blob data. May include unsaved editor buffers."),
                  consequence: String(localized: "Review before removing."),
                  developer: app),
            .init(rel: ".trash", risk: .safe,
                  why: String(localized: "\(app) internal trash."),
                  consequence: String(localized: "Removed."),
                  developer: app),
        ]

        var out: [CleanupCandidate] = []
        for b in buckets {
            if ctx.isCancelled() { break }
            let url = root.appendingPathComponent(b.rel)
            guard DirListing.exists(url) else { continue }
            if let c = await ctx.candidate(
                scannerID: "cursor:\(app):\(b.rel)",
                name: "\(app) / \(b.rel)",
                url: url,
                risk: b.risk,
                explanation: b.why,
                consequence: b.consequence,
                category: .cursorIDE,
                developer: b.developer
            ) {
                out.append(c)
            }
        }

        // Break down large globalStorage children by extension id.
        let global = root.appendingPathComponent("User/globalStorage")
        for child in DirListing.children(of: global, dirsOnly: true) {
            if ctx.isCancelled() { break }
            guard let size = await ctx.measured(child), size >= 80_000_000 else { continue }
            out.append(CleanupCandidate(
                scannerID: "cursor:\(app):global:\(child.lastPathComponent)",
                name: "\(app) · \(child.lastPathComponent)",
                path: child, size: size,
                risk: .reviewRequired,
                category: .cursorIDE,
                developer: child.lastPathComponent,
                confidence: .medium,
                isRegenerable: false,
                explanation: String(localized: "Storage owned by the \(child.lastPathComponent) extension inside \(app) globalStorage. This can be indexes, chat history or model caches — not ordinary cache."),
                consequence: String(localized: "The extension may re-download data or lose local history."),
                lastModified: DirListing.modified(child)
            ))
        }
        return out
    }
}
