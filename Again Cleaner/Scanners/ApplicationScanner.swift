//
//  ApplicationScanner.swift
//  Again Cleaner
//
//  Lists large installed apps by size. These are NOT junk — the section exists
//  so the user can see where space went and choose to uninstall. Every item is
//  System Protected (no delete button in Smart Clean); removal is manual via
//  Reveal in Finder.
//

import Foundation

nonisolated struct ApplicationScanner: CleanupScanner {
    let id = "applications"
    let displayName = "Large Applications"

    private nonisolated static let minSize: Int64 = 500_000_000   // 500 MB
    private nonisolated static let roots = [
        "/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    func isAvailable() -> Bool {
        Self.roots.contains { FileManager.default.fileExists(atPath: $0) }
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let fm = FileManager.default
        var out: [CleanupCandidate] = []

        for rootPath in Self.roots {
            let root = URL(fileURLWithPath: rootPath)
            let apps = (try? fm.contentsOfDirectory(at: root,
                includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for app in apps where app.pathExtension == "app" {
                if ctx.isCancelled() { break }
                let size = await ctx.usage.size(of: app, isCancelled: ctx.isCancelled)
                guard size >= Self.minSize else { continue }
                out.append(CleanupCandidate(
                    scannerID: "app:\(app.lastPathComponent)",
                    name: app.deletingPathExtension().lastPathComponent,
                    path: app, size: size, risk: .systemProtected,
                    explanation: String(localized: "An installed application — not junk. Shown so you can see what uses space."),
                    consequence: String(localized: "Use Reveal in Finder to uninstall if you no longer need it."),
                    method: .manualOnly
                ))
            }
        }
        return out
    }
}
