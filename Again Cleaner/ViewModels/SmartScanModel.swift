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
            onProgress: { [weak self] fraction in self?.progress = fraction }
        )

        candidates = found
        // Pre-tick everything Smart Clean is allowed to remove automatically.
        selected = Set(found.filter { CleanupSafetyPolicy.isSmartCleanEligible($0) }.map(\.id))
        isScanning = false
        hasScanned = true
    }

    func cancel() {
        token.cancel()
        isScanning = false
    }

    // MARK: - Grouping

    /// Candidates grouped by risk, in risk order, each group size-sorted.
    var groups: [(risk: CleanupRisk, items: [CleanupCandidate])] {
        CleanupRisk.allCases.compactMap { risk in
            let items = candidates.filter { $0.risk == risk }.sorted { $0.size > $1.size }
            return items.isEmpty ? nil : (risk, items)
        }
    }

    func size(of risk: CleanupRisk) -> Int64 {
        candidates.filter { $0.risk == risk }.reduce(0) { $0 + $1.size }
    }

    var totalFound: Int64 { candidates.reduce(0) { $0 + $1.size } }

    // MARK: - Selection

    func isSelected(_ c: CleanupCandidate) -> Bool { selected.contains(c.id) }

    func toggle(_ c: CleanupCandidate) {
        guard c.risk.isDeletable else { return }
        if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) }
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

    /// Select exactly what the preset covers (from the current scan).
    func applyPreset() {
        selected = Set(presetMatches.map(\.id))
    }

    /// One-click: select the preset and clean it.
    func quickClean() async {
        applyPreset()
        await cleanSelected()
    }

    // MARK: - Reveal

    func reveal(_ c: CleanupCandidate) {
        guard let url = c.path else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
