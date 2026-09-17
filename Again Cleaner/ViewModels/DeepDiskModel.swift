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

    @Published var sortKey: ScanSortKey = .size
    @Published var sizeFilter: ClosedRange<Int64> = 0...0

    private let usage = DiskUsageService()
    private var token = CancelToken()

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

    var largestChild: Int64 { children.first?.size ?? 0 }

    /// The full size span of the current level — the range slider's travel limits.
    var sizeBounds: ClosedRange<Int64> { SizeRangeSlider.bounds(for: children.map(\.size)) }

    /// `children` narrowed by `sizeFilter` and ordered by `sortKey`.
    var displayedChildren: [DiskChild] {
        let filtered = sizeBounds.upperBound > sizeBounds.lowerBound
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

    func load(_ url: URL) async {
        token.cancel()
        let token = CancelToken()
        self.token = token

        isLoading = true
        root = url
        children = []
        volume = DiskSpace.snapshot()

        let stayOnVolume = url.path == "/"
        let kids = await usage.children(
            of: url, stayOnVolume: stayOnVolume,
            isCancelled: { token.isCancelled }
        )
        guard !token.isCancelled else { isLoading = false; return }
        children = kids
        // A new level was just loaded — start the range filter fully open so
        // nothing is hidden until the user deliberately narrows it.
        sizeFilter = SizeRangeSlider.bounds(for: kids.map(\.size))
        isLoading = false
    }

    func cancel() {
        token.cancel()
        isLoading = false
    }

    func drill(into child: DiskChild) async {
        guard child.isDirectory else { return }
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
