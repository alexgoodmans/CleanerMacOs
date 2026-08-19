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

struct BuiltinCatalogScanner: CleanupScanner {
    let id = "builtin-catalog"
    let displayName = "General Cleanup"

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []

        for category in CleanupCatalog.all {
            if ctx.isCancelled() { break }
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
        case .regeneratable:
            return String(localized: "The app or tool will recreate or re-download it as needed.")
        case .reviewRequired:
            return String(localized: "May contain data you want to keep — review before removing.")
        case .dangerous:
            return String(localized: "Could remove important data — manual action only.")
        case .systemProtected:
            return String(localized: "Protected by the system — shown for size only.")
        }
    }

    private static func modified(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
