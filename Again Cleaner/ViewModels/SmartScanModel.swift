//
//  SmartScanModel.swift
//  Again Cleaner
//
//  Drives the new analyzer screen: runs every scanner in parallel, groups the
//  candidates by risk, and cleans the selection through the policy-gated
//  executor with a real before/after disk measurement. Kept separate from the
//  existing CleanerViewModel so the current UI is untouched.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SmartScanModel: ObservableObject {

    @Published private(set) var candidates: [CleanupCandidate] = []
    @Published private(set) var isScanning = false
    @Published private(set) var progress = 0.0
    @Published private(set) var isCleaning = false
    @Published private(set) var lastReport: CleanupReport?
    @Published var hasScanned = false

    @Published var selected: Set<UUID> = []
    @Published var moveToTrash = true

    /// Apps that are running and would be affected by the current selection.
    /// Non-empty means the clean is paused until the user quits them.
    @Published private(set) var runningBlockers: [String] = []

    private let coordinator = ScanCoordinator.standard
    private let executor = CleanupExecutor()
    private var token = CancelToken()

    // Quick-clean preset: the scanner ids the user cleaned last time.
    private let presetKey = "cleanPresetScannerIDs"
    @Published private(set) var preset: Set<String> = []

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: presetKey) ?? []
        preset = Set(saved)
    }

    // MARK: - Scan

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        progress = 0
        candidates = []
        selected = []
        lastReport = nil
        runningBlockers = []

        let token = CancelToken()
        self.token = token

        let found = await coordinator.scanAll(
            isCancelled: { token.isCancelled },
            onProgress: { [weak self] fraction in self?.progress = fraction },
            onPartial: { [weak self] chunk in
                guard let self else { return }
                let ignored = IgnoreStore.paths()
                let fresh = chunk.filter { c in
                    guard let url = c.path else { return true }
                    return !ignored.contains(PathGuard.canonicalPath(url))
                }
                self.candidates.append(contentsOf: fresh)
            }
        )

        let ignored = IgnoreStore.paths()
        candidates = found.filter { c in
            guard let url = c.path else { return true }
            return !ignored.contains(PathGuard.canonicalPath(url))
        }
        // Pre-tick ONLY the narrowest, least ambiguous tier (logs/trash). Never
        // pre-select "usually safe" caches — a scanner heuristic guessing wrong
        // here is exactly what has caused real data loss. Everything beyond
        // `.safe` requires the user to look and opt in themselves.
        selected = Set(candidates.filter { CleanupSafetyPolicy.isPreselected($0) }.map(\.id))
        isScanning = false
        hasScanned = true
    }

    func cancel() {
        token.cancel()
        isScanning = false
    }

    // MARK: - Grouping

    /// Candidates grouped by category, largest category first.
    var categoryGroups: [(category: ScanCategory, items: [CleanupCandidate])] {
        let grouped = Dictionary(grouping: candidates, by: \.category)
        return grouped.keys
            .map { cat in (cat, grouped[cat]!.sorted { $0.size > $1.size }) }
            .sorted { lhs, rhs in
                lhs.items.reduce(Int64(0)) { $0 + $1.size } > rhs.items.reduce(0) { $0 + $1.size }
            }
    }

    var safeBytes: Int64 {
        candidates.filter { $0.contributesToTotals && $0.risk.isAutoSelectable }
            .reduce(0) { $0 + $1.reclaimableBytes }
    }

    var reviewBytes: Int64 {
        candidates.filter { $0.contributesToTotals && $0.risk == .reviewRequired }
            .reduce(0) { $0 + $1.reclaimableBytes }
    }

    var selectedReviewBytes: Int64 { selectedBytes(for: .reviewRequired) }
    var selectedSafeBytes: Int64 {
        selectedBytes(for: .safe) + selectedBytes(for: .usuallySafe)
    }

    var estimatedFreeAfter: Int64 {
        DiskSpace.snapshot().available + selectedItems().reduce(0) { $0 + $1.reclaimableBytes }
    }

    func ignore(_ c: CleanupCandidate) {
        guard let url = c.path else { return }
        IgnoreStore.ignore(url)
        selected.remove(c.id)
        candidates.removeAll { $0.id == c.id }
    }

    func size(of risk: CleanupRisk) -> Int64 {
        candidates.filter { $0.risk == risk }.reduce(0) { $0 + $1.size }
    }

    var totalFound: Int64 {
        candidates.filter(\.contributesToTotals).reduce(0) { $0 + $1.size }
    }

    // MARK: - Selection

    func isSelected(_ c: CleanupCandidate) -> Bool { selected.contains(c.id) }

    func toggle(_ c: CleanupCandidate) {
        guard c.canUserDelete else { return }
        if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) }
    }

    /// Items in a category group that the user is allowed to tick.
    func selectableItems(in items: [CleanupCandidate]) -> [CleanupCandidate] {
        items.filter(\.canUserDelete)
    }

    enum GroupTick: Equatable {
        case none, partial, all

        var symbol: String {
            switch self {
            case .none:    return "square"
            case .partial: return "minus.square.fill"
            case .all:     return "checkmark.square.fill"
            }
        }
    }

    func groupTick(for items: [CleanupCandidate]) -> GroupTick {
        let ids = selectableItems(in: items).map(\.id)
        guard !ids.isEmpty else { return .none }
        let hit = ids.filter { selected.contains($0) }.count
        if hit == 0 { return .none }
        if hit == ids.count { return .all }
        return .partial
    }

    /// Select every deletable item in the group, or clear the group if it is already fully selected.
    func toggleGroup(_ items: [CleanupCandidate]) {
        let ids = selectableItems(in: items).map(\.id)
        guard !ids.isEmpty else { return }
        if groupTick(for: items) == .all {
            selected.subtract(ids)
        } else {
            selected.formUnion(ids)
        }
    }

    /// Select only what Smart Clean may auto-remove (safe + regeneratable).
    func selectSmart() {
        selected = Set(candidates.filter { CleanupSafetyPolicy.isSmartCleanEligible($0) }.map(\.id))
    }

    func selectedItems() -> [CleanupCandidate] {
        candidates.filter { selected.contains($0.id) }
    }

    var selectedBytes: Int64 { selectedItems().reduce(0) { $0 + $1.size } }

    func selectedBytes(for risk: CleanupRisk) -> Int64 {
        selectedItems().filter { $0.risk == risk }.reduce(0) { $0 + $1.size }
    }

    // MARK: - Clean

    func cleanSelected(force: Bool = false) async {
        guard !isCleaning else { return }
        let items = selectedItems()
        guard !items.isEmpty else { return }

        // Process detection: don't clean a running app's data unless forced.
        if !force {
            let blockers = RunningAppGuard.blockingApps(for: items)
            if !blockers.isEmpty { runningBlockers = blockers; return }
        }
        runningBlockers = []
        isCleaning = true

        let selectedIDs = Set(items.map(\.id))
        let report = await executor.clean(items, toTrash: moveToTrash)

        // Remember what was cleaned as the quick-clean preset (only the
        // auto-cleanable kinds, so replay stays safe).
        rememberPreset(from: items, skipped: report.skipped)

        // Remove from the list everything that was selected and NOT skipped.
        let skippedNames = Set(report.skipped.map(\.name))
        candidates.removeAll { c in
            selectedIDs.contains(c.id) && !skippedNames.contains(c.name)
        }
        selected = selected.intersection(Set(candidates.map(\.id)))

        lastReport = report
        isCleaning = false
    }

    /// Quit the blocking apps, wait for them to exit, then clean.
    func quitAndClean() async {
        let names = runningBlockers
        guard !names.isEmpty else { return }
        RunningAppGuard.quit(names)
        try? await Task.sleep(for: .seconds(1.5))
        runningBlockers = []
        await cleanSelected(force: true)
    }

    func dismissBlockers() { runningBlockers = [] }

    // MARK: - Quick-clean preset

    private func rememberPreset(from items: [CleanupCandidate],
                                skipped: [(name: String, reason: String)]) {
        let skippedNames = Set(skipped.map(\.name))
        let cleaned = items.filter {
            $0.risk.isAutoSelectable && !skippedNames.contains($0.name)
        }
        guard !cleaned.isEmpty else { return }
        preset = Set(cleaned.map(\.scannerID))
        UserDefaults.standard.set(Array(preset), forKey: presetKey)
    }

    /// Whether a saved preset exists and matches anything in the current scan.
    var hasPreset: Bool { !preset.isEmpty }

    var presetMatches: [CleanupCandidate] {
        candidates.filter { preset.contains($0.scannerID) && $0.risk.isDeletable }
    }

    var presetBytes: Int64 { presetMatches.reduce(0) { $0 + $1.size } }

    /// Select exactly what the preset covers (from the current scan). Cleaning
    /// still requires the confirmation sheet — Quick Clean used to skip it and
    /// clean immediately on a single click, which is exactly the kind of
    /// no-review path that has caused real data loss. It no longer does that;
    /// the UI must show the preview sheet after calling this.
    func applyPreset() {
        selected = Set(presetMatches.map(\.id))
    }

    // MARK: - Large Applications: uninstall + leftovers

    private let usage = DiskUsageService()

    func isApp(_ c: CleanupCandidate) -> Bool { c.scannerID.hasPrefix("app:") }

    private func bundleID(of c: CleanupCandidate) -> String? {
        guard isApp(c) else { return nil }
        return String(c.scannerID.dropFirst("app:".count))
    }

    /// Move an application to the Trash (guarded by PathGuard — system apps are
    /// refused). Then drop it from the list.
    func uninstall(_ c: CleanupCandidate) async {
        guard isApp(c), let url = c.path else { return }
        _ = await Task.detached(priority: .userInitiated) {
            FileSystemEngine.remove([url], toTrash: true)
        }.value
        candidates.removeAll { $0.id == c.id }
        selected.remove(c.id)
    }

    /// Search the standard support locations for data left by `c`'s app and add
    /// any matches as Review candidates. Matches on the exact bundle id only.
    func findLeftovers(for c: CleanupCandidate) async {
        guard let bundleID = bundleID(of: c) else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        let target = bundleID.lowercased()
        var found: [CleanupCandidate] = []
        let existing = Set(candidates.map(\.scannerID))

        for (rel, confidence) in LeftoverScanner.strictDirs {
            let dir = home.appendingPathComponent(rel)
            let entries = (try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for url in entries {
                let id = LeftoverMatching.bundleID(fromFileName: url.lastPathComponent)
                guard id.lowercased() == target else { continue }
                let sid = "leftover:\(id)"
                guard !existing.contains(sid), !found.contains(where: { $0.scannerID == sid && $0.path == url }) else { continue }
                let size = await usage.size(of: url)
                guard size > 0 else { continue }
                found.append(CleanupCandidate(
                    scannerID: sid,
                    name: "\(id) — leftover",
                    path: url, size: size, risk: .reviewRequired,
                    explanation: String(localized: "Data left by “\(bundleID)” after uninstall. Confidence: \(confidence)."),
                    consequence: String(localized: "Review before removing — safe to delete if you're done with the app."),
                    method: .filesystem
                ))
            }
        }
        candidates.append(contentsOf: found)
    }

    // MARK: - Reveal

    func reveal(_ c: CleanupCandidate) {
        guard let url = c.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
