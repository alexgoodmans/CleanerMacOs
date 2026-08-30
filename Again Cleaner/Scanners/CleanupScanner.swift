//
//  CleanupScanner.swift
//  Again Cleaner
//
//  The new modular scan architecture. Each source of junk is its own scanner
//  producing `CleanupCandidate`s, run in parallel by the coordinator. This
//  replaces the "one giant cleaner" shape without touching the current,
//  working catalog path — scanners are added alongside it.
//

import Foundation

/// Shared services + cancellation handed to every scanner.
nonisolated struct ScanContext: Sendable {
    let usage: DiskUsageService
    let isCancelled: @Sendable () -> Bool
}

/// One source of disk junk. Implementations are stateless and Sendable so the
/// coordinator can fan them out with a TaskGroup.
nonisolated protocol CleanupScanner: Sendable {
    /// Stable identifier, e.g. "xcode", "docker".
    var id: String { get }
    /// Human-readable section name for the UI.
    var displayName: String { get }
    /// Whether this scanner is applicable on this machine (tool installed, path
    /// exists…). Checked before `scan` so absent tools cost nothing.
    func isAvailable() -> Bool
    /// Produce candidates. Must honour `ctx.isCancelled`.
    func scan(_ ctx: ScanContext) async -> [CleanupCandidate]
}

extension CleanupScanner {
    nonisolated func isAvailable() -> Bool { true }
}
