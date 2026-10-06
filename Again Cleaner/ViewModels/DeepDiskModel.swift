//
//  DeepDiskModel.swift
//  Again Cleaner
//
//  Drives the Deep Disk Scan: a `du -xhd 1`-style size tree the user drills
//  into. Uses volume-aware sizing so scanning `/` never double-counts the APFS
//  Data volume as System, and reports real free space from system APIs.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class DeepDiskModel: ObservableObject {

    @Published private(set) var root: URL
    @Published private(set) var children: [DiskChild] = []
    @Published private(set) var isLoading = false
    @Published private(set) var volume = DiskSpace.Snapshot(total: 0, available: 0)

    /// Ids of children listed but still being measured (rows show a spinner).
    @Published private(set) var pending: Set<String> = []

    @Published var sortKey: ScanSortKey = .size
    @Published var sizeFilter: ClosedRange<Int64> = 0...0

    private var token = CancelToken()

    /// How many children are measured at once — enough to keep an SSD busy
    /// without starving the rest of the system.
    private static let parallelism = 4

    struct Root: Identifiable { let id = UUID(); let name: String; let url: URL }

    static let quickRoots: [Root] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            Root(name: "Home", url: home),
            Root(name: "Library", url: home.appendingPathComponent("Library")),
            Root(name: "/Library", url: URL(fileURLWithPath: "/Library")),
            Root(name: "/private", url: URL(fileURLWithPath: "/private")),
            Root(name: "/opt", url: URL(fileURLWithPath: "/opt")),
            Root(name: "/Applications", url: URL(fileURLWithPath: "/Applications")),
            Root(name: "/ (volume)", url: URL(fileURLWithPath: "/")),
        ]
    }()

    init() {
        root = FileManager.default.homeDirectoryForCurrentUser
    }

    var isAtVolumeRoot: Bool { root.path == "/" }
    var canGoUp: Bool { root.path != "/" }

    /// Path components as breadcrumb chips.
    var breadcrumb: [(name: String, url: URL)] {
        var acc: [(String, URL)] = []
        var url = URL(fileURLWithPath: "/")
        acc.append(("/", url))
        for comp in root.pathComponents.dropFirst() where !comp.isEmpty {
            url.appendPathComponent(comp)
            acc.append((comp, url))
        }
        return acc
    }

    var largestChild: Int64 { children.map(\.size).max() ?? 0 }

    var measuredCount: Int { children.count - pending.count }
    var measuredTotal: Int64 { children.reduce(0) { $0 + $1.size } }

    func isPending(_ child: DiskChild) -> Bool { pending.contains(child.id) }

    /// The full size span of the current level — the range slider's travel limits.
    var sizeBounds: ClosedRange<Int64> { SizeRangeSlider.bounds(for: children.map(\.size)) }

    /// `children` narrowed by `sizeFilter` and ordered by `sortKey`. The size
    /// filter only applies once the level is fully measured — mid-load the
    /// bounds are still moving and unmeasured rows would be hidden.
    var displayedChildren: [DiskChild] {
        let filtered = !isLoading && sizeBounds.upperBound > sizeBounds.lowerBound
            ? children.filter { sizeFilter.contains($0.size) }
            : children
        switch sortKey {
        case .size:
            return filtered.sorted { $0.size > $1.size }
        case .name:
            return filtered.sorted {
                $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            }
        case .date:
            return filtered.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        }
    }

    /// List `url` immediately, then measure its children in parallel and fill
    /// in each size as soon as it's known — so a big level (home, `/`) shows
    /// its contents at once instead of an empty list for minutes.
    func load(_ url: URL) async {
        token.cancel()
        let token = CancelToken()
        self.token = token

        isLoading = true
        root = url
        children = []
        pending = []
        volume = DiskSpace.snapshot()

        let entries = await Task.detached(priority: .userInitiated) {
            DiskUsageService.listing(of: url)
        }.value
        guard self.token === token else { return }

        children = entries.map {
            DiskChild(url: $0.url, size: $0.volumeUsage ?? 0, isDirectory: $0.isDirectory,
                      modified: $0.modified, isCloud: $0.isCloud,
                      isVolume: $0.volumeUsage != nil)
        }
        // Cloud-sync roots are listed but never walked; APFS service volumes
        // already carry their size (see DiskUsageService).
        let measurable = entries.filter { !$0.isCloud && $0.volumeUsage == nil }
        pending = Set(measurable.map(\.url.path))

        let excluded = PathGuard.canonicalPath(url) == "/" ? DiskUsageService.volumeRootExclusions : []

        await withTaskGroup(of: (id: String, size: Int64).self) { group in
            var queue = measurable.makeIterator()
            for _ in 0..<Self.parallelism {
                guard let entry = queue.next() else { break }
                group.addTask { await Self.measure(entry, excluding: excluded, token: token) }
            }
            for await result in group {
                // A newer load replaced this one — drain quietly, touch nothing.
                guard self.token === token else { continue }
                if let i = children.firstIndex(where: { $0.id == result.id }) {
                    let c = children[i]
                    children[i] = DiskChild(url: c.url, size: result.size, isDirectory: c.isDirectory,
                                            modified: c.modified, isCloud: c.isCloud, isVolume: c.isVolume)
                }
                pending.remove(result.id)
                if !token.isCancelled, let entry = queue.next() {
                    group.addTask { await Self.measure(entry, excluding: excluded, token: token) }
                }
            }
        }

        guard self.token === token else { return }
        children.removeAll { $0.size == 0 && !$0.isCloud }
        pending = []
        // Level fully measured — start the range filter fully open so nothing
        // is hidden until the user deliberately narrows it.
        sizeFilter = SizeRangeSlider.bounds(for: children.map(\.size))
        isLoading = false
    }

    /// Measure one child off the main actor (detached: never inherits it).
    private nonisolated static func measure(
        _ entry: DiskUsageService.Entry, excluding excluded: [String], token: CancelToken
    ) async -> (id: String, size: Int64) {
        let size = await Task.detached(priority: .userInitiated) {
            DiskUsageService.measure(entry.url, excluding: excluded, isCancelled: { token.isCancelled })
        }.value
        return (entry.url.path, size)
    }

    /// Stop measuring. Sizes found so far stay on screen; rows that weren't
    /// reached are dropped rather than shown as 0.
    func cancel() {
        token.cancel()
        token = CancelToken()   // detach the running load so it can't touch state
        children.removeAll { pending.contains($0.id) || ($0.size == 0 && !$0.isCloud) }
        pending = []
        sizeFilter = SizeRangeSlider.bounds(for: children.map(\.size))
        isLoading = false
    }

    func drill(into child: DiskChild) async {
        // Listing inside a cloud-sync root can block on its File Provider;
        // service volumes are root-only and managed by macOS.
        guard child.isDirectory, !child.isCloud, !child.isVolume else { return }
        await load(child.url)
    }

    func goUp() async {
        guard canGoUp else { return }
        await load(root.deletingLastPathComponent())
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
