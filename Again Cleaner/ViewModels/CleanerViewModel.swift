//
//  CleanerViewModel.swift
//  Again Cleaner
//
//  Owns all UI state and drives the FileSystemEngine off the main actor.
//

import Foundation
import SwiftUI
import Combine
import os

/// Thread-safe boolean shared between the main actor (which sets it) and a
/// background scan (which polls it). Avoids hopping actors on every file.
nonisolated final class CancelToken: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)
    func cancel() { lock.withLock { $0 = true } }
    var isCancelled: Bool { lock.withLock { $0 } }
}

@MainActor
final class CleanerViewModel: ObservableObject {

    // Disk
    @Published var disk = DiskInfo(total: 0, free: 0)

    // Junk categories
    @Published private(set) var categories: [JunkCategory] = CleanupCatalog.all
    @Published var results: [String: CategoryScanResult] = [:]   // keyed by category id
    @Published var selected: Set<String> = []
    @Published var isScanningJunk = false
    @Published var junkProgress = 0.0

    // Large files
    @Published var largeFiles: [LargeFile] = []
    @Published var isScanningFiles = false
    @Published var largeFileThresholdMB: Double = 500
    @Published var largeFileKind: FileKind? = nil     // nil = all types
    @Published var largeFileSort: ScanSortKey = .size
    @Published var largeFileSizeFilter: ClosedRange<Int64> = 0...0
    private var largeScanToken = CancelToken()

    /// The full size span of what was found — the range slider's travel limits.
    var largeFileSizeBounds: ClosedRange<Int64> { SizeRangeSlider.bounds(for: largeFiles.map(\.size)) }

    /// Large files after the type + size-range filters, ordered by `largeFileSort`.
    var filteredLargeFiles: [LargeFile] {
        var files = largeFiles
        if let kind = largeFileKind { files = files.filter { $0.kind == kind } }
        if largeFileSizeBounds.upperBound > largeFileSizeBounds.lowerBound {
            files = files.filter { largeFileSizeFilter.contains($0.size) }
        }
        switch largeFileSort {
        case .size:
            return files.sorted { $0.size > $1.size }
        case .name:
            return files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date:
            return files.sorted { $0.modified > $1.modified }
        }
    }

    /// Type filters that actually appear in the current results (with counts).
    var largeFileKinds: [(kind: FileKind, count: Int)] {
        let groups = Dictionary(grouping: largeFiles, by: \.kind)
        return FileKind.allCases.compactMap { k in
            let c = groups[k]?.count ?? 0
            return c > 0 ? (k, c) : nil
        }
    }

    // Cleaning
    @Published var moveToTrash = true
    @Published var isCleaning = false
    @Published var lastReclaimed: Int64 = 0
    @Published var showReclaimedBanner = false

    // Per-row file preview (expanded category rows)
    @Published var expanded: Set<String> = []
    @Published var itemsByCategory: [String: [TargetItem]] = [:]
    /// Per category, the item paths currently ticked for removal. Absence of an
    /// entry means "not loaded yet — treat the whole category as selected".
    @Published var itemSelected: [String: Set<String>] = [:]

    // Favorites (user-picked folders for one-click cleanup)
    @Published private(set) var favorites: [FavoriteFolder] = []
    @Published var isScanningFavorites = false
    private let favoritesKey = "favoriteFolderPaths"

    init() {
        loadFavorites()
    }

    // MARK: - Derived

    var totalReclaimable: Int64 {
        results.values.reduce(0) { $0 + $1.size }
    }

    var selectedReclaimable: Int64 {
        categories
            .filter { selected.contains($0.id) }
            .reduce(Int64(0)) { $0 + reclaimable(for: $1) }
    }

    /// Reclaimable size for a category, honouring per-item ticks when the row
    /// has been expanded (otherwise the whole measured size).
    func reclaimable(for category: JunkCategory) -> Int64 {
        if let items = itemsByCategory[category.id], let sel = itemSelected[category.id] {
            return items.filter { sel.contains($0.path) }.reduce(0) { $0 + $1.size }
        }
        return scannedSize(for: category)
    }

    /// Size from the last scan — does not change when a row is expanded or when
    /// individual files are ticked. Used for sort order so the table stays still.
    func scannedSize(for category: JunkCategory) -> Int64 {
        results[category.id]?.size ?? 0
    }

    @Published var junkSizeFilter: ClosedRange<Int64> = 0...0

    /// The full size span of every found category — the range slider's travel limits.
    var junkSizeBounds: ClosedRange<Int64> {
        SizeRangeSlider.bounds(for: categories.compactMap { results[$0.id]?.size }.filter { $0 > 0 })
    }

    /// Categories that exist on disk (size > 0 or still scanning) and fall
    /// within the size-range filter, safest first.
    var visibleCategories: [JunkCategory] {
        let inRange = junkSizeBounds.upperBound > junkSizeBounds.lowerBound
        return categories.filter { cat in
            guard let r = results[cat.id] else { return isScanningJunk }
            if r.isScanning { return true }
            guard r.size > 0 else { return false }
            return !inRange || junkSizeFilter.contains(r.size)
        }
    }

    // Sorting for the junk list.
    enum JunkSort: String, CaseIterable, Identifiable {
        case `default` = "Default"
        case name = "Name"
        case size = "Size"
        case favorite = "Favorite"
        case date = "Date"
        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .default:  return "list.bullet"
            case .name:     return "textformat"
            case .size:     return "arrow.up.arrow.down"
            case .favorite: return "star"
            case .date:     return "calendar"
            }
        }
    }

    @Published var junkSort: JunkSort = .default

    /// `visibleCategories` ordered by the current sort choice.
    /// Size/favorite sorts use the *scanned* size, not the live ticked subset,
    /// so expanding a row or unticking files does not reshuffle the table.
    var sortedVisibleCategories: [JunkCategory] {
        let cats = visibleCategories
        switch junkSort {
        case .default:
            return cats
        case .name:
            return cats.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .size:
            return cats.sorted { a, b in
                let sa = scannedSize(for: a), sb = scannedSize(for: b)
                if sa != sb { return sa > sb }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .favorite:
            // Favorited first, then by scanned size within each group.
            return cats.sorted { a, b in
                let fa = isFavorited(a), fb = isFavorited(b)
                if fa != fb { return fa }
                let sa = scannedSize(for: a), sb = scannedSize(for: b)
                if sa != sb { return sa > sb }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .date:
            // Newest first; categories without a date sink to the bottom.
            return cats.sorted { a, b in
                switch (results[a.id]?.modified, results[b.id]?.modified) {
                case let (x?, y?):
                    if x != y { return x > y }
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):
                    let sa = scannedSize(for: a), sb = scannedSize(for: b)
                    if sa != sb { return sa > sb }
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                }
            }
        }
    }

    // MARK: - Lifecycle

    func refreshDisk() {
        disk = FileSystemEngine.diskInfo()
    }

    /// APFS reports freed space with a delay (especially after trashing), so
    /// re-measure a few times after a clean to let the gauge catch up.
    func refreshDiskSoon() {
        refreshDisk()
        Task { [weak self] in
            for delay in [1.5, 4.0, 8.0] {
                try? await Task.sleep(for: .seconds(delay))
                self?.refreshDisk()
            }
        }
    }

    // MARK: - Junk scan

    func scanJunk() async {
        guard !isScanningJunk else { return }
        isScanningJunk = true
        junkProgress = 0
        selected.removeAll()
        // Seed placeholders so rows can show a spinner immediately.
        results = Dictionary(uniqueKeysWithValues: categories.map {
            ($0.id, CategoryScanResult(id: $0.id, size: 0, itemCount: 0, isScanning: true))
        })

        let cats = categories
        let total = cats.count
        var done = 0

        await withTaskGroup(of: CategoryScanResult.self) { group in
            for cat in cats {
                group.addTask {
                    let (targets, size) = FileSystemEngine.resolve(cat)
                    return CategoryScanResult(
                        id: cat.id, size: size,
                        itemCount: targets.count, isScanning: false,
                        modified: FileSystemEngine.newestModified(of: targets)
                    )
                }
            }
            for await result in group {
                results[result.id] = result
                // Auto-select ONLY confirmed-safe categories (logs, trash).
                // "Caution" categories are a heuristic guess about where a
                // folder lives, not a guarantee about what's inside it — an
                // incident where that guess was wrong showed pre-ticking them
                // silently is not acceptable. The user must opt in themselves.
                if let cat = cats.first(where: { $0.id == result.id }),
                   cat.safety == .safe, result.size > 0 {
                    selected.insert(result.id)
                }
                done += 1
                junkProgress = Double(done) / Double(total)
            }
        }

        // A fresh scan starts the range filter fully open so nothing found is
        // hidden until the user deliberately narrows it.
        junkSizeFilter = SizeRangeSlider.bounds(for: categories.compactMap { results[$0.id]?.size }.filter { $0 > 0 })
        isScanningJunk = false
        refreshDisk()
    }

    // MARK: - Cleaning

    func cleanSelected() async {
        guard !isCleaning, !selected.isEmpty else { return }
        isCleaning = true
        let toClean = categories.filter { selected.contains($0.id) }
        let trash = moveToTrash

        // Resolve the exact URLs to remove on the main actor, honouring per-item
        // ticks where the row was expanded, else the whole category.
        let jobs: [(id: String, rule: CleanRule, urls: [URL])] = toClean.map { cat in
            if let items = itemsByCategory[cat.id], let sel = itemSelected[cat.id] {
                let urls = items.filter { sel.contains($0.path) }.map(\.url)
                return (cat.id, cat.rule, urls)
            }
            return (cat.id, cat.rule, FileSystemEngine.existingTargets(for: cat.rule))
        }

        // Remove, then re-measure each touched category so partially-cleaned
        // ones keep an accurate remaining size.
        let (reclaimed, newSizes): (Int64, [String: (Int64, Int)]) =
        await Task.detached(priority: .userInitiated) {
            var total: Int64 = 0
            var sizes: [String: (Int64, Int)] = [:]
            for job in jobs {
                total += FileSystemEngine.remove(job.urls, toTrash: trash)
                let remaining = FileSystemEngine.existingTargets(for: job.rule)
                let size = remaining.reduce(Int64(0)) { $0 + FileSystemEngine.size(of: $1) }
                sizes[job.id] = (size, remaining.count)
            }
            return (total, sizes)
        }.value

        for (id, info) in newSizes {
            results[id] = CategoryScanResult(id: id, size: info.0,
                                             itemCount: info.1, isScanning: false)
            selected.remove(id)
            expanded.remove(id)
            itemsByCategory[id] = nil
            itemSelected[id] = nil
        }

        lastReclaimed = reclaimed
        showReclaimedBanner = true
        isCleaning = false
        refreshDiskSoon()
    }

    // MARK: - Row file preview

    /// Expand or collapse a category's file preview, loading its items lazily.
    func toggleExpand(_ category: JunkCategory) async {
        if expanded.contains(category.id) {
            expanded.remove(category.id)
            return
        }
        expanded.insert(category.id)
        guard itemsByCategory[category.id] == nil else { return }
        let rule = category.rule
        let items = await Task.detached(priority: .userInitiated) {
            FileSystemEngine.targetItems(for: rule)
        }.value
        itemsByCategory[category.id] = items
        // Item ticks mirror the parent checkbox on first expand: a selected
        // category opens fully ticked, an unselected one fully unticked.
        if itemSelected[category.id] == nil {
            itemSelected[category.id] = selected.contains(category.id)
                ? Set(items.map(\.path)) : []
        }
    }

    /// Toggle a category. Ticking cascades down: all its items get selected;
    /// unticking clears every item tick as well.
    func toggleCategory(_ category: JunkCategory) {
        let id = category.id
        if selected.contains(id) {
            selected.remove(id)
            if itemsByCategory[id] != nil { itemSelected[id] = [] }
        } else {
            selected.insert(id)
            if let items = itemsByCategory[id] {
                itemSelected[id] = Set(items.map(\.path))
            }
        }
    }

    /// Categories that showed up in the scan with something to clean.
    var foundCategories: [JunkCategory] {
        categories.filter { (results[$0.id]?.size ?? 0) > 0 }
    }

    /// Master checkbox state for the whole found list.
    var allFoundSelected: Bool {
        let found = foundCategories
        return !found.isEmpty && found.allSatisfy { selected.contains($0.id) }
    }

    /// Select or deselect every found category (cascading into item ticks).
    func setAllCategories(_ value: Bool) {
        for cat in foundCategories {
            if value {
                selected.insert(cat.id)
                if let items = itemsByCategory[cat.id] {
                    itemSelected[cat.id] = Set(items.map(\.path))
                }
            } else {
                selected.remove(cat.id)
                if itemsByCategory[cat.id] != nil { itemSelected[cat.id] = [] }
            }
        }
    }

    func isItemSelected(_ categoryID: String, _ item: TargetItem) -> Bool {
        // Nil selection means "not customised yet" → treated as fully selected.
        itemSelected[categoryID]?.contains(item.path) ?? true
    }

    func toggleItem(_ categoryID: String, _ item: TargetItem) {
        var set = itemSelected[categoryID]
            ?? Set((itemsByCategory[categoryID] ?? []).map(\.path))
        if set.contains(item.path) { set.remove(item.path) } else { set.insert(item.path) }
        itemSelected[categoryID] = set
        // Keep the category checkbox in sync: no items ticked → deselect it.
        if set.isEmpty { selected.remove(categoryID) }
        else { selected.insert(categoryID) }
    }

    func setAllItems(_ categoryID: String, selected value: Bool) {
        let all = (itemsByCategory[categoryID] ?? []).map(\.path)
        itemSelected[categoryID] = value ? Set(all) : []
        if value { selected.insert(categoryID) } else { selected.remove(categoryID) }
    }

    // MARK: - Favorites

    private func loadFavorites() {
        let paths = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        favorites = paths.map { FavoriteFolder(url: URL(fileURLWithPath: $0)) }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(favorites.map(\.path), forKey: favoritesKey)
    }

    func addFavorite(_ url: URL) {
        guard !favorites.contains(where: { $0.path == url.path }) else { return }
        favorites.append(FavoriteFolder(url: url))
        saveFavorites()
        Task { await scanFavorites() }
    }

    func removeFavorite(_ favorite: FavoriteFolder) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }

    func isFavorite(_ url: URL) -> Bool {
        favorites.contains { $0.path == url.path }
    }

    func toggleFavorite(_ url: URL) {
        if let fav = favorites.first(where: { $0.path == url.path }) {
            removeFavorite(fav)
        } else {
            addFavorite(url)
        }
    }

    /// A category counts as favourited when all of its folders are pinned.
    func isFavorited(_ category: JunkCategory) -> Bool {
        let urls = category.rule.favoritableURLs
        return !urls.isEmpty && urls.allSatisfy { isFavorite($0) }
    }

    func toggleFavorite(_ category: JunkCategory) {
        if isFavorited(category) {
            for url in category.rule.favoritableURLs {
                if let fav = favorites.first(where: { $0.path == url.path }) {
                    removeFavorite(fav)
                }
            }
        } else {
            for url in category.rule.favoritableURLs where !isFavorite(url) {
                addFavorite(url)
            }
        }
    }

    var favoritesTotal: Int64 { favorites.reduce(0) { $0 + $1.size } }

    func scanFavorites() async {
        guard !favorites.isEmpty else { return }
        isScanningFavorites = true
        for i in favorites.indices { favorites[i].isScanning = true }

        let urls = favorites.map(\.url)
        let sizes = await Task.detached(priority: .userInitiated) { () -> [String: Int64] in
            var out: [String: Int64] = [:]
            for url in urls { out[url.path] = FileSystemEngine.size(of: url) }
            return out
        }.value

        for i in favorites.indices {
            favorites[i].size = sizes[favorites[i].path] ?? 0
            favorites[i].isScanning = false
        }
        isScanningFavorites = false
    }

    /// Empty the contents of every favourite folder (the folders themselves stay).
    func cleanFavorites() async {
        guard !isCleaning, !favorites.isEmpty else { return }
        isCleaning = true
        let urls = favorites.map(\.url)
        let trash = moveToTrash

        let reclaimed = await Task.detached(priority: .userInitiated) { () -> Int64 in
            var total: Int64 = 0
            for dir in urls {
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil, options: [])) ?? []
                total += FileSystemEngine.remove(children, toTrash: trash)
            }
            return total
        }.value

        lastReclaimed = reclaimed
        showReclaimedBanner = true
        isCleaning = false
        await scanFavorites()
        refreshDiskSoon()
    }

    // MARK: - Large files

    func scanLargeFiles() async {
        guard !isScanningFiles else { return }
        isScanningFiles = true
        let token = CancelToken()
        largeScanToken = token
        largeFiles = []

        let root = FileManager.default.homeDirectoryForCurrentUser
        let minBytes = Int64(largeFileThresholdMB * 1_000_000)

        let files = await Task.detached(priority: .userInitiated) {
            FileSystemEngine.largeFiles(under: root, minSize: minBytes) {
                token.isCancelled
            }
        }.value

        largeFiles = files
        // A fresh scan starts the range filter fully open so nothing found is
        // hidden until the user deliberately narrows it.
        largeFileSizeFilter = SizeRangeSlider.bounds(for: files.map(\.size))
        isScanningFiles = false
    }

    func cancelLargeScan() {
        largeScanToken.cancel()
        isScanningFiles = false
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func deleteLargeFile(_ file: LargeFile) {
        let trash = moveToTrash
        FileSystemEngine.remove([file.url], toTrash: trash)
        largeFiles.removeAll { $0.id == file.id }
        refreshDiskSoon()
    }
}
