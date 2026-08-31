//
//  APFSSnapshotScanner.swift
//  Again Cleaner
//
//  Lists local APFS (Time Machine) snapshots. These hold "purgeable" space
//  macOS usually reclaims on its own; they are shown for awareness only and
//  never deleted by the app — thinning is a system operation
//  (`tmutil thinlocalsnapshots`) the user performs deliberately.
//

import Foundation

nonisolated struct APFSSnapshotScanner: CleanupScanner {
    let id = "apfs-snapshots"
    let displayName = "Local APFS Snapshots"

    func isAvailable() -> Bool { FileManager.default.fileExists(atPath: "/usr/bin/tmutil") }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        guard let out = try? await ProcessRunner.run(
            "/usr/bin/tmutil", ["listlocalsnapshots", "/"], timeout: .seconds(10)),
            out.ok else { return [] }

        let snapshots = Self.parse(out.stdout)
        guard !snapshots.isEmpty else { return [] }

        return [CleanupCandidate(
            scannerID: "apfs:snapshots",
            name: String(localized: "Local APFS Snapshots (\(snapshots.count))"),
            path: nil, size: 0, risk: .reviewRequired,
            explanation: String(localized: "\(snapshots.count) Time Machine local snapshot(s). They occupy purgeable space macOS frees automatically when the disk fills."),
            consequence: String(localized: "Thins local snapshots via `tmutil thinlocalsnapshots`. Actual space freed is shown after. May require privileges on some systems."),
            method: .tmutil
        )]
    }

    /// Extract snapshot identifiers from `tmutil listlocalsnapshots /`.
    nonisolated static func parse(_ output: String) -> [String] {
        output.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("com.apple.TimeMachine") }
    }
}
