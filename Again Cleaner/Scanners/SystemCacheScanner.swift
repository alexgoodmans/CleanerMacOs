//
//  SystemCacheScanner.swift
//  Again Cleaner
//
//  /Library/Caches when readable. If the sandbox (or permissions) block it,
//  the UI shows that cleanup requires a system-authorized action — we never
//  pretend a zero-byte folder is empty.
//

import Foundation

nonisolated struct SystemCacheScanner: CleanupScanner {
    let id = "syscache"
    let displayName = "System Caches"

    private static let root = URL(fileURLWithPath: "/Library/Caches")
    private static let minSize: Int64 = 50_000_000

    var ownedPrefixes: [URL] { [Self.root] }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        guard DirListing.exists(Self.root) else { return [] }
        guard DirListing.isReadable(Self.root) else {
            return [CleanupCandidate(
                scannerID: "syscache:blocked",
                name: String(localized: "System caches"),
                path: Self.root, size: 0,
                risk: .neverDeleteAutomatically,
                category: .systemStorage,
                confidence: .unknown,
                requiresAdmin: true,
                explanation: String(localized: "Detected but requires manual/system-authorized cleanup. Again Cleaner cannot read /Library/Caches under current permissions (App Sandbox / TCC)."),
                consequence: String(localized: "Use System Settings or a privileged tool. Again Cleaner will not escalate privileges."),
                method: .manualOnly,
                accessState: .permissionRequired
            )]
        }
        var out: [CleanupCandidate] = []
        for child in DirListing.children(of: Self.root, dirsOnly: true) {
            if ctx.isCancelled() { break }
            guard let size = await ctx.measured(child), size >= Self.minSize else { continue }
            let isApple = child.lastPathComponent.hasPrefix("com.apple.")
            out.append(CleanupCandidate(
                scannerID: "syscache:\(child.lastPathComponent)",
                name: child.lastPathComponent,
                path: child, size: size,
                risk: isApple ? .neverDeleteAutomatically : .reviewRequired,
                category: .systemStorage,
                developer: child.lastPathComponent,
                confidence: .medium,
                requiresAdmin: true,
                explanation: isApple
                    ? String(localized: "Apple system cache (\(child.lastPathComponent)). Detected but requires manual/system-authorized cleanup — Again Cleaner will not delete it automatically.")
                    : String(localized: "System-level cache for \(child.lastPathComponent). May need administrator privileges to remove."),
                consequence: isApple
                    ? String(localized: "Leave it. macOS manages this cache.")
                    : String(localized: "Removing may require an admin password. The app will recreate the cache."),
                lastModified: DirListing.modified(child),
                method: isApple ? .manualOnly : .filesystem
            ))
        }
        return out
    }
}
