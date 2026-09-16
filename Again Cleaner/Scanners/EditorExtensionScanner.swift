//
//  EditorExtensionScanner.swift
//  Again Cleaner
//
//  Groups VS Code-family extension folders by ID and flags every version
//  except the newest as stale (usuallySafe). The current version is kept.
//

import Foundation

nonisolated struct EditorExtensionScanner: CleanupScanner {
    let id = "editor-ext"
    let displayName = "Editor Extensions"

    private struct Root {
        let name: String
        let url: URL
    }

    private static func roots() -> [Root] {
        let home = DirListing.home
        return [
            Root(name: "Cursor", url: home.appendingPathComponent(".cursor/extensions")),
            Root(name: "VS Code", url: home.appendingPathComponent(".vscode/extensions")),
        ]
    }

    var ownedPrefixes: [URL] { Self.roots().map(\.url) }

    func isAvailable() -> Bool {
        Self.roots().contains { DirListing.exists($0.url) }
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for root in Self.roots() {
            if ctx.isCancelled() { break }
            guard DirListing.exists(root.url) else { continue }
            let folders = DirListing.children(of: root.url, dirsOnly: true)
            let groups = EditorExtensionParsing.groups(from: folders.map(\.lastPathComponent))
            let byName = Dictionary(uniqueKeysWithValues: folders.map { ($0.lastPathComponent, $0) })

            for group in groups {
                if ctx.isCancelled() { break }
                guard let newestURL = byName[group.newest.folderName] else { continue }

                // Current version — keep.
                if let c = await ctx.candidate(
                    scannerID: "editor-ext:\(root.name):\(group.extensionID):current",
                    name: "\(root.name) · \(group.extensionID) (current \(group.newest.version))",
                    url: newestURL,
                    risk: .neverDeleteAutomatically,
                    explanation: String(localized: "Currently installed version of this \(root.name) extension (\(group.installedCount) version(s) on disk). Not removed automatically."),
                    consequence: String(localized: "Protected — this is the newest installed version."),
                    category: .cursorIDE, developer: root.name,
                    method: .manualOnly
                ) { out.append(c) }

                guard !group.stale.isEmpty else { continue }
                var staleBytes: Int64 = 0
                for stale in group.stale {
                    guard let url = byName[stale.folderName] else { continue }
                    if let c = await ctx.candidate(
                        scannerID: "editor-ext:\(root.name):\(group.extensionID):\(stale.version)",
                        name: "\(root.name) · \(group.extensionID) \(stale.version) (old)",
                        url: url,
                        risk: .usuallySafe,
                        explanation: String(localized: "\(root.name) keeps multiple installed versions of some extensions. Again Cleaner found an older version (\(stale.version)); current is \(group.newest.version)."),
                        consequence: String(localized: "Removed. The current version keeps working. Reinstall the old version from the marketplace if you need it."),
                        category: .cursorIDE, subcategory: group.extensionID, developer: root.name
                    ) {
                        staleBytes += c.size
                        out.append(c)
                    }
                }
                _ = staleBytes
            }
        }
        return out
    }
}
