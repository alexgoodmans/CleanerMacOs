//
//  CacheScanner.swift
//  Again Cleaner
//
//  Enumerates ~/Library/Caches per application/vendor instead of offering
//  the whole folder as one deletion target.
//

import Foundation

nonisolated struct CacheScanner: CleanupScanner {
    let id = "caches"
    let displayName = "App Caches"

    private static func root() -> URL {
        DirListing.home.appendingPathComponent("Library/Caches")
    }

    var ownedPrefixes: [URL] { [Self.root()] }

    func isAvailable() -> Bool { DirListing.exists(Self.root()) }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let root = Self.root()
        guard DirListing.isReadable(root) else {
            return [CleanupCandidate(
                scannerID: "cache:inaccessible",
                name: String(localized: "User caches (inaccessible)"),
                path: root, size: 0, risk: .neverDeleteAutomatically,
                category: .appCaches, confidence: .unknown,
                explanation: String(localized: "Again Cleaner cannot read ~/Library/Caches."),
                consequence: String(localized: "Grant folder access and rescan."),
                method: .manualOnly, accessState: .inaccessible
            )]
        }
        var out: [CleanupCandidate] = []
        for child in DirListing.children(of: root, dirsOnly: true) {
            if ctx.isCancelled() { break }
            let vendor = Self.vendor(for: child.lastPathComponent)
            if let c = await ctx.candidate(
                scannerID: "cache:\(child.lastPathComponent)",
                name: vendor,
                url: child,
                risk: .usuallySafe,
                explanation: String(localized: "Application cache for \(vendor). Caches are regenerated the next time the app runs."),
                consequence: String(localized: "The app recreates this cache on demand. Close the app first if it is running."),
                category: .appCaches,
                developer: vendor
            ) { out.append(c) }
        }
        return out
    }

    private static func vendor(for folder: String) -> String {
        if folder.contains("."), let last = folder.split(separator: ".").last {
            return last.prefix(1).uppercased() + last.dropFirst()
        }
        return folder
    }
}
