//
//  ScanCoordinator.swift
//  Again Cleaner
//
//  Runs all available scanners in parallel and aggregates their candidates.
//  Reports progress as each scanner finishes so the UI never blocks.
//

import Foundation

struct ScanCoordinator: Sendable {
    let scanners: [CleanupScanner]

    /// The default set of scanners. For now just the catalog bridge; dedicated
    /// scanners (Xcode, Docker, Homebrew…) are appended here as they land.
    static var standard: ScanCoordinator {
        ScanCoordinator(scanners: [
            BuiltinCatalogScanner(),
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
            return all.sorted { $0.size > $1.size }
        }
    }
}
