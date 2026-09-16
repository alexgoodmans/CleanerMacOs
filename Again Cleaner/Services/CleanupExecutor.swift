//
//  CleanupExecutor.swift
//  Again Cleaner
//
//  Performs cleanup for a set of candidates. Every filesystem delete passes
//  through CleanupSafetyPolicy first; non-filesystem methods (Docker/brew/
//  tmutil) are dispatched to their tools and land in later phases. Measures
//  real disk space before/after so the UI shows what was ACTUALLY recovered.
//

import Foundation

struct CleanupReport: Sendable {
    var expectedBytes: Int64 = 0        // summed size of what we tried to remove
    var removedCount: Int = 0
    var skipped: [(name: String, reason: String)] = []
    var before: DiskSpace.Snapshot
    var after: DiskSpace.Snapshot

    /// Honest number: real free-space delta, not the sum of file sizes.
    var actuallyRecovered: Int64 {
        DiskSpace.actuallyRecovered(before: before, after: after)
    }
}

nonisolated struct CleanupExecutor: Sendable {

    /// Remove the given candidates. `toTrash` moves filesystem items to the
    /// Trash (recoverable) instead of unlinking. Runs off the main actor.
    func clean(
        _ candidates: [CleanupCandidate],
        toTrash: Bool
    ) async -> CleanupReport {
        let before = DiskSpace.snapshot()
        var report = CleanupReport(before: before, after: before)

        let filesystemURLs = candidates.compactMap { c -> URL? in
            guard c.method == .filesystem else { return nil }
            return c.path
        }

        for candidate in candidates {
            // Gate: risk + PathGuard. Never trust the caller.
            let verdict = CleanupSafetyPolicy.verdict(for: candidate)
            guard verdict.isAllowed else {
                if case let .blocked(reason) = verdict {
                    report.skipped.append((candidate.name, reason))
                }
                continue
            }

            switch candidate.method {
            case .filesystem:
                guard let url = candidate.path else {
                    report.skipped.append((candidate.name, "no path"))
                    continue
                }
                // Re-validate immediately before unlink (symlink retarget, race).
                let now = PathGuard.verdict(for: url)
                guard now.isAllowed else {
                    if case let .blocked(reason) = now {
                        report.skipped.append((candidate.name, reason))
                    }
                    continue
                }
                // Never delete a recognised project root (source lives here).
                let listing = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
                if ProjectRootDetector.isProjectRoot(contents: listing) {
                    report.skipped.append((candidate.name, "refusing to delete a project root"))
                    continue
                }
                // If a selected ancestor covers this path, skip the child.
                if Self.hasSelectedAncestor(url, in: filesystemURLs) {
                    continue
                }
                let freed = FileSystemEngine.remove([url], toTrash: toTrash)
                if freed > 0 || !FileManager.default.fileExists(atPath: url.path) {
                    report.expectedBytes += candidate.size
                    report.removedCount += 1
                } else {
                    report.skipped.append((candidate.name, "could not remove"))
                }

            case .dockerBuilderPrune:
                if await runTool(ProcessRunner.locate("docker"),
                                 ["builder", "prune", "-f"], timeout: .seconds(120)) {
                    report.expectedBytes += candidate.size
                    report.removedCount += 1
                } else {
                    report.skipped.append((candidate.name, "docker builder prune failed"))
                }

            case .dockerImagePrune:
                if await runTool(ProcessRunner.locate("docker"),
                                 ["image", "prune", "-f"], timeout: .seconds(120)) {
                    report.expectedBytes += candidate.size
                    report.removedCount += 1
                } else {
                    report.skipped.append((candidate.name, "docker image prune failed"))
                }

            case .dockerVolumeRemove:
                // Individual volumes stay opt-in via the Docker CLI so we never
                // `rm -rf` a named volume's mount. The volume name is `name`.
                let vol = candidate.subcategory ?? candidate.name
                if await runTool(ProcessRunner.locate("docker"),
                                 ["volume", "rm", vol], timeout: .seconds(60)) {
                    report.expectedBytes += candidate.size
                    report.removedCount += 1
                } else {
                    report.skipped.append((candidate.name, "docker volume rm failed"))
                }

            case .homebrewCleanup:
                if await runTool(ProcessRunner.locate("brew"),
                                 ["cleanup"], timeout: .seconds(120)) {
                    report.expectedBytes += candidate.size
                    report.removedCount += 1
                } else {
                    report.skipped.append((candidate.name, "brew cleanup failed"))
                }

            case .tmutil:
                // Ask macOS to thin local APFS snapshots via the sanctioned tool.
                // A large purge amount + urgency 4 = "reclaim as much as possible".
                // This may require privileges on some systems; report honestly.
                if await runTool("/usr/bin/tmutil",
                                 ["thinlocalsnapshots", "/", "999999999999", "4"],
                                 timeout: .seconds(120)) {
                    report.removedCount += 1
                } else {
                    report.skipped.append((candidate.name, "tmutil thinning failed (may require privileges)"))
                }

            case .manualOnly:
                report.skipped.append((candidate.name, "manual only"))
            }
        }

        // APFS frees space with a slight delay; a short settle gives a truer
        // "after" reading than measuring instantly.
        try? await Task.sleep(for: .seconds(1))
        report.after = DiskSpace.snapshot()
        return report
    }

    /// True when another selected URL is a strict ancestor of `url`.
    nonisolated static func hasSelectedAncestor(_ url: URL, in selected: [URL]) -> Bool {
        selected.contains { PathGuard.isStrictChild(url, of: $0) }
    }

    /// Run a CLI cleanup tool; returns whether it exited successfully.
    private func runTool(_ path: String?, _ args: [String], timeout: Duration) async -> Bool {
        guard let path else { return false }
        return (try? await ProcessRunner.run(path, args, timeout: timeout))?.ok ?? false
    }
}
