//
//  LeftoverScanner.swift
//  Again Cleaner
//
//  Finds data left behind by apps that are no longer installed. It matches ONLY
//  on exact bundle identifiers (never name substrings) and never touches Apple/
//  system ids, so it won't mistake a live app's data for junk. Everything is
//  Review Required — leftovers are shown with a confidence score, never
//  auto-deleted.
//

import Foundation

nonisolated struct LeftoverScanner: CleanupScanner {
    let id = "leftovers"
    let displayName = "Leftover App Data"

    /// Locations keyed strictly by bundle id, and how confident a match is.
    private nonisolated static let strictDirs: [(rel: String, confidence: String)] = [
        // Strictly bundle-id-keyed by macOS → high confidence.
        ("Library/Containers", "Certain"),
        ("Library/HTTPStorages", "Certain"),
        ("Library/Saved Application State", "Certain"),
        ("Library/WebKit", "Certain"),
        // Usually bundle-id-named, occasionally app-named → still likely.
        ("Library/Application Support", "Very likely"),
        ("Library/Caches", "Very likely"),
        ("Library/Logs", "Very likely"),
        // Preference DOMAINS often differ from the .app bundle id (JetBrains,
        // helpers…), so a no-match here is only a hint.
        ("Library/Preferences", "Possible"),
    ]

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let installed = InstalledApps.bundleIDs()
        var out: [CleanupCandidate] = []
        var seenIDs: Set<String> = []   // avoid the same orphan from many dirs dominating

        for (rel, confidence) in Self.strictDirs {
            if ctx.isCancelled() { break }
            let dir = home.appendingPathComponent(rel)
            let entries = (try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])) ?? []

            for url in entries {
                if ctx.isCancelled() { break }
                let bundleID = LeftoverMatching.bundleID(fromFileName: url.lastPathComponent)
                guard LeftoverMatching.isOrphan(bundleID, installed: installed) else { continue }

                let size = await ctx.usage.size(of: url, isCancelled: ctx.isCancelled)
                guard size > 0 else { continue }

                let key = bundleID.lowercased() + "|" + url.lastPathComponent
                guard !seenIDs.contains(key) else { continue }
                seenIDs.insert(key)

                out.append(CleanupCandidate(
                    scannerID: "leftover:\(bundleID)",
                    name: "\(bundleID) — leftover",
                    path: url, size: size, risk: .reviewRequired,
                    explanation: String(localized: "Data from “\(bundleID)”, which is no longer installed. Confidence: \(confidence)."),
                    consequence: String(localized: "Review before removing — reinstalling the app would lose these settings/data."),
                    lastModified: try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                    method: .filesystem
                ))
            }
        }
        return out
    }
}
