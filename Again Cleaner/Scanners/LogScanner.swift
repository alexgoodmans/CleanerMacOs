//
//  LogScanner.swift
//  Again Cleaner
//
//  Per-application logs under ~/Library/Logs, with oldest/newest dates.
//

import Foundation

nonisolated struct LogScanner: CleanupScanner {
    let id = "logs"
    let displayName = "Logs"

    private static func root() -> URL {
        DirListing.home.appendingPathComponent("Library/Logs")
    }

    var ownedPrefixes: [URL] { [Self.root()] }

    func isAvailable() -> Bool { DirListing.exists(Self.root()) }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let root = Self.root()
        var out: [CleanupCandidate] = []
        for child in DirListing.children(of: root) {
            if ctx.isCancelled() { break }
            let range = DirListing.dateRange(of: child)
            let newest = DirListing.shortDate(range.newest ?? DirListing.modified(child))
            let oldest = DirListing.shortDate(range.oldest ?? range.newest)
            if let c = await ctx.candidate(
                scannerID: "log:\(child.lastPathComponent)",
                name: child.lastPathComponent,
                url: child,
                risk: .safe,
                explanation: String(localized: "Diagnostic logs for \(child.lastPathComponent). Oldest: \(oldest). Newest: \(newest). Logs are regenerable."),
                consequence: String(localized: "Removed. The application will write new logs as needed."),
                category: .logs,
                developer: child.lastPathComponent
            ) { out.append(c) }
        }
        return out
    }
}
