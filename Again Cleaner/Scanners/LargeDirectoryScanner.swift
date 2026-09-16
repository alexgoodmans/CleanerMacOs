//
//  LargeDirectoryScanner.swift
//  Again Cleaner
//
//  Discovery of huge folders. Large ≠ junk. Unknown directories are never
//  offered as safe cleanup.
//

import Foundation

nonisolated struct LargeDirectoryScanner: CleanupScanner {
    let id = "large-dir"
    let displayName = "Large Directories"

    private static let minSize: Int64 = 5_000_000_000
    private static let skip: Set<String> = [
        "Library", "Pictures", "Music", "Movies", "Applications",
        ".Trash", "Downloads",
    ]

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let home = DirListing.home
        var out: [CleanupCandidate] = []
        for child in DirListing.children(of: home, dirsOnly: true) {
            if ctx.isCancelled() { break }
            if Self.skip.contains(child.lastPathComponent) { continue }
            guard let size = await ctx.measured(child), size >= Self.minSize else { continue }
            if ProjectRootDetector.isProjectRoot(
                contents: (try? FileManager.default.contentsOfDirectory(atPath: child.path)) ?? []
            ) {
                out.append(CleanupCandidate(
                    scannerID: "large-dir:\(child.lastPathComponent)",
                    name: child.lastPathComponent,
                    path: child, size: size,
                    risk: .neverDeleteAutomatically,
                    category: .largeFiles,
                    confidence: .high,
                    isRegenerable: false,
                    explanation: String(localized: "We found a \(DirListing.bytes(size)) project directory. Source projects are not junk."),
                    consequence: String(localized: "Protected. Use Developer Junk to clean build artifacts inside it."),
                    lastModified: DirListing.modified(child),
                    method: .manualOnly
                ))
                continue
            }
            out.append(CleanupCandidate(
                scannerID: "large-dir:\(child.lastPathComponent)",
                name: child.lastPathComponent,
                path: child, size: size,
                risk: .neverDeleteAutomatically,
                category: .largeFiles,
                confidence: .unknown,
                isRegenerable: false,
                explanation: String(localized: "We found a \(DirListing.bytes(size)) directory, but Again Cleaner cannot verify that its contents are regenerable. Large does not mean junk."),
                consequence: String(localized: "Shown for discovery only. Inspect in Deep Disk Scan or Finder."),
                lastModified: DirListing.modified(child),
                method: .manualOnly
            ))
        }
        return out
    }
}
