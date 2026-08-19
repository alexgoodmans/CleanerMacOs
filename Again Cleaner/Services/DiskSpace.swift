//
//  DiskSpace.swift
//  Again Cleaner
//
//  Real free-space measurement via system APIs (not `du` sums), plus a
//  before/after helper. On APFS the honest number to show the user is
//  "important usage" available capacity, which accounts for purgeable space.
//

import Foundation

enum DiskSpace {

    struct Snapshot: Sendable {
        let total: Int64
        let available: Int64
        var used: Int64 { max(0, total - available) }
    }

    /// Current capacity of the volume backing the home directory.
    nonisolated static func snapshot() -> Snapshot {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let v = try? url.resourceValues(forKeys: keys) else {
            return Snapshot(total: 0, available: 0)
        }
        return Snapshot(
            total: Int64(v.volumeTotalCapacity ?? 0),
            available: v.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }

    /// Actual bytes freed between two snapshots — the truth the UI should show
    /// instead of the summed size of removed files (APFS clones, snapshots and
    /// purgeable space make the two differ).
    nonisolated static func actuallyRecovered(before: Snapshot, after: Snapshot) -> Int64 {
        max(0, after.available - before.available)
    }
}
