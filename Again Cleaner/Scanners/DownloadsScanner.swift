//
//  DownloadsScanner.swift
//  Again Cleaner
//
//  Large files in ~/Downloads. Review required — installers are not assumed
//  to be leftover junk.
//

import Foundation

nonisolated struct DownloadsScanner: CleanupScanner {
    let id = "downloads"
    let displayName = "Large Downloads"

    private static let minSize: Int64 = 100_000_000

    var ownedPrefixes: [URL] {
        [DirListing.home.appendingPathComponent("Downloads")]
    }

    func isAvailable() -> Bool {
        DirListing.exists(DirListing.home.appendingPathComponent("Downloads"))
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let dir = DirListing.home.appendingPathComponent("Downloads")
        var out: [CleanupCandidate] = []
        for item in DirListing.children(of: dir) {
            if ctx.isCancelled() { break }
            guard let size = await ctx.measured(item), size >= Self.minSize else { continue }
            let kind = FileKind.of(item)
            let extra: String
            switch kind {
            case .installer, .diskImage, .archive:
                extra = String(localized: "This looks like an installer or archive. It may no longer be needed after installation/extraction, but Again Cleaner will not assume that.")
            default:
                extra = String(localized: "A large file in Downloads. Not classified as junk.")
            }
            out.append(CleanupCandidate(
                scannerID: "download:\(item.lastPathComponent)",
                name: item.lastPathComponent,
                path: item, size: size,
                risk: .reviewRequired,
                category: .largeDownloads,
                subcategory: kind.rawValue,
                confidence: .medium,
                isRegenerable: false,
                explanation: extra,
                consequence: String(localized: "Deleting removes the file from Downloads. Keep it if you still need the installer, firmware or archive."),
                lastModified: DirListing.modified(item)
            ))
        }
        return out
    }
}
