//
//  TempScanner.swift
//  Again Cleaner
//
//  /tmp (/private/tmp), entry by entry. Only the user's own regular files and
//  folders are listed — live sockets, IPC/system names and anything holding a
//  socket are never offered (see TempFileRules). Entries untouched for 3+ days
//  are Usually Safe; newer ones are Review Required because a running app may
//  still be using them. Nothing here is pre-selected.
//

import Foundation

nonisolated struct TempScanner: CleanupScanner {
    let id = "tmp"
    let displayName = "Temporary Files"

    private static let root = URL(fileURLWithPath: "/private/tmp")

    var ownedPrefixes: [URL] { [Self.root] }

    func isAvailable() -> Bool { DirListing.exists(Self.root) }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for (item, verdict) in TempFileRules.candidates(in: Self.root) {
            if ctx.isCancelled() { break }
            let old = verdict == .old
            let when = DirListing.shortDate(item.newestModified)
            if let c = await ctx.candidate(
                scannerID: "tmp:\(item.name)",
                name: item.name,
                url: item.url,
                risk: old ? .usuallySafe : .reviewRequired,
                explanation: old
                    ? String(localized: "Your temporary item in /tmp, unchanged since \(when). macOS clears /tmp on restart anyway. Sockets and system items in /tmp are never listed.")
                    : String(localized: "Your temporary item in /tmp, changed recently (\(when)). A running app may still be using it."),
                consequence: old
                    ? String(localized: "Removed. Anything that still needs it recreates it.")
                    : String(localized: "Review first — removing a file an app is using can break that app until it restarts."),
                category: .tempFiles
            ) {
                out.append(c)
            }
        }
        return out
    }
}
