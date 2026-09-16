//
//  BuiltinCatalogScanner.swift
//  Again Cleaner
//
//  Bridges the existing, battle-tested CleanupCatalog into the new scanner
//  world so NOT A SINGLE current category is lost. Every catalog category's
//  resolved targets become individual `CleanupCandidate`s carrying the mapped
//  5-level risk. This lets the new UI/executor consume the old catalog while
//  dedicated scanners (Xcode, Docker…) are built out on top.
//

import Foundation

nonisolated struct BuiltinCatalogScanner: CleanupScanner {
    let id = "builtin-catalog"
    let displayName = "General Cleanup"

    /// Categories now owned by dedicated scanners (richer breakdown).
    private static let coveredByDedicatedScanner: Set<String> = [
        "user-logs", "gradle", "xcode-derived", "xcode-archives",
        "xcode-devicesupport", "ios-simulators", "xcode-devicelogs",
        "cursor", "vscode", "node-modules", "build-dirs",
        "downloads-old", "android-cache", "appsupport-large",
    ]

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []

        for category in CleanupCatalog.all {
            if ctx.isCancelled() { break }
            if Self.coveredByDedicatedScanner.contains(category.id) { continue }
            if category.id.hasPrefix("cache:") { continue }
            let risk = category.safety.risk
            let targets = FileSystemEngine.existingTargets(for: category.rule)

            for url in targets {
                if ctx.isCancelled() { break }
                let size = await ctx.usage.size(of: url, isCancelled: ctx.isCancelled)
                guard size > 0 else { continue }

                out.append(CleanupCandidate(
                    scannerID: "builtin:\(category.id)",
                    name: url.lastPathComponent,
                    path: url,
                    size: size,
                    risk: risk,
                    explanation: category.subtitle,
                    consequence: Self.consequence(for: risk),
                    lastModified: Self.modified(of: url),
                    method: .filesystem
                ))
            }
        }
        return out
    }

    private static func consequence(for risk: CleanupRisk) -> String {
        switch risk {
        case .safe:
            return String(localized: "Removed permanently — no effect on your work.")
        case .usuallySafe:
            return String(localized: "The app or tool will recreate or re-download it as needed.")
        case .reviewRequired:
            return String(localized: "May contain data you want to keep — review before removing.")
        case .dangerous:
            return String(localized: "Could remove important data — manual action only.")
        case .neverDeleteAutomatically:
            return String(localized: "Shown for size only — Again Cleaner will not delete this automatically.")
        }
    }

    private static func modified(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
