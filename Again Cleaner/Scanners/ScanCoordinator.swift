//
//  ScanCoordinator.swift
//  Again Cleaner
//
//  Runs all available scanners in parallel and aggregates their candidates.
//  Reports progress as each scanner finishes so the UI never blocks.
//

import Foundation

nonisolated struct ScanCoordinator: Sendable {
    let scanners: [CleanupScanner]

    /// The default set of scanners. For now just the catalog bridge; dedicated
    /// scanners (Xcode, Docker, Homebrew…) are appended here as they land.
    static var standard: ScanCoordinator {
        ScanCoordinator(scanners: [
            BuiltinCatalogScanner(),
            DeviceSupportScanner(),
            CursorScanner(),
            ArduinoScanner(),
            ApplicationScanner(),
            APFSSnapshotScanner(),
            LeftoverScanner(),
            DockerScanner(),
            HomebrewScanner(),
        ])
    }

    /// Scan every available scanner concurrently. `onProgress` is called on the
    /// main actor after each scanner completes (fraction 0…1).
    func scanAll(
        isCancelled: @Sendable @escaping () -> Bool = { false },
        onProgress: @MainActor @Sendable @escaping (Double) -> Void = { _ in }
    ) async -> [CleanupCandidate] {
        let active = scanners.filter { $0.isAvailable() }
        guard !active.isEmpty else { return [] }

        let usage = DiskUsageService()
        let total = active.count

        return await withTaskGroup(of: [CleanupCandidate].self) { group in
            for scanner in active {
                group.addTask {
                    let ctx = ScanContext(usage: usage, isCancelled: isCancelled)
                    return await scanner.scan(ctx)
                }
            }

            var all: [CleanupCandidate] = []
            var done = 0
            for await candidates in group {
                all.append(contentsOf: candidates)
                done += 1
                let fraction = Double(done) / Double(total)
                await onProgress(fraction)
            }
            return Self.dedupe(all, owners: ownedPrefixes()).sorted { $0.size > $1.size }
        }
    }

    /// Canonical prefixes owned by dedicated (non-catalog) scanners.
    private func ownedPrefixes() -> [String] {
        scanners
            .filter { $0.id != "builtin-catalog" }
            .flatMap { $0.ownedPrefixes }
            .map { PathGuard.canonicalPath($0) }
    }

    /// Drop generic catalog candidates that a dedicated scanner already covers,
    /// then remove any exact-path duplicates (keeping the dedicated one).
    nonisolated static func dedupe(_ items: [CleanupCandidate], owners: [String]) -> [CleanupCandidate] {
        func isBuiltin(_ c: CleanupCandidate) -> Bool { c.scannerID.hasPrefix("builtin:") }

        let afterOwnership = items.filter { c in
            guard isBuiltin(c), let url = c.path else { return true }
            let path = PathGuard.canonicalPath(url)
            return !owners.contains { path == $0 || path.hasPrefix($0 + "/") }
        }

        // Exact-path de-dup: dedicated scanners win over builtin.
        var seen: Set<String> = []
        var result: [CleanupCandidate] = []
        for c in afterOwnership.sorted(by: { !isBuiltin($0) && isBuiltin($1) }) {
            if let url = c.path {
                let key = PathGuard.canonicalPath(url)
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            result.append(c)
        }
        return result
    }
}
