//
//  FileSystemEngine.swift
//  Again Cleaner
//
//  Low-level, UI-agnostic file-system work: measuring sizes, reading disk
//  capacity, resolving a category's targets, and removing them.
//  Everything here is `nonisolated` and safe to call off the main actor.
//

import Foundation

struct FileSystemEngine {

    private nonisolated(unsafe) static let fm = FileManager.default

    // MARK: - Disk capacity

    nonisolated static func diskInfo() -> DiskInfo {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return DiskInfo(total: 0, free: 0)
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        return DiskInfo(total: total, free: free)
    }

    // MARK: - Size measurement

    /// Sum of the allocated size of every file under `url` (recursively).
    /// Uses allocated size so the number matches what the disk actually frees.
    nonisolated static func size(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            return allocatedSize(of: url)
        }

        var total: Int64 = 0
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            total += allocatedSize(of: fileURL)
        }
        return total
    }

    private nonisolated static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let v = try? url.resourceValues(forKeys: keys) else { return 0 }
        if v.isRegularFile == false { return 0 }
        return Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }

    // MARK: - Resolving a category to concrete targets

    /// The concrete paths that cleaning a category would delete, along with the
    /// measured reclaimable size. Only existing paths are returned.
    nonisolated static func resolve(_ category: JunkCategory) -> (targets: [URL], size: Int64) {
        let targets = existingTargets(for: category.rule)
        let total = targets.reduce(Int64(0)) { $0 + size(of: $1) }
        return (targets, total)
    }

    /// The paths that will actually be removed on clean.
    /// - `clearContents`: the *children* of each directory.
    /// - `removePaths`: the paths themselves.
    /// - `findDirs`: matching directories found under root.
    nonisolated static func existingTargets(for rule: CleanRule) -> [URL] {
        switch rule {
        case .clearContents(let dirs):
            return dirs.flatMap { children(of: $0) }

        case .removePaths(let paths):
            return paths.filter { fm.fileExists(atPath: $0.path) }

        case .findDirs(let root, let names):
            return findDirectories(named: Set(names), under: root)

        case .oldItems(let dir, let days):
            return staleItems(in: dir, olderThanDays: days)
        }
    }

    /// Top-level items in `dir` whose most recent modification is older than the
    /// cutoff. Only the immediate children are considered — never recurses into
    /// user files, so nothing recently touched is ever offered up.
    private nonisolated static func staleItems(in dir: URL, olderThanDays days: Int) -> [URL] {
        guard fm.fileExists(atPath: dir.path) else { return [] }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .addedToDirectoryDateKey]
        let items = (try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return items.filter { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            let modified = v?.contentModificationDate ?? .distantPast
            return modified < cutoff
        }
    }

    /// Concrete removable items for a rule, each measured, biggest first.
    /// Used to show a file-level preview under an expanded category row.
    nonisolated static func targetItems(for rule: CleanRule) -> [TargetItem] {
        existingTargets(for: rule).map { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return TargetItem(url: url, size: size(of: url), isDirectory: isDir)
        }
        .sorted { $0.size > $1.size }
    }

    private nonisolated static func children(of dir: URL) -> [URL] {
        (try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []
    }

    /// Depth-first search for directories whose name is in `names`. Matches are
    /// not descended into (a `node_modules` inside a `node_modules` is covered
    /// by removing the parent).
    private nonisolated static func findDirectories(named names: Set<String>, under root: URL) -> [URL] {
        guard fm.fileExists(atPath: root.path) else { return [] }
        var matches: [URL] = []
        let keys: [URLResourceKey] = [.isDirectoryKey]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return [] }

        for case let url as URL in enumerator {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            if names.contains(url.lastPathComponent) {
                matches.append(url)
                enumerator.skipDescendants()
            }
        }
        return matches
    }

    // MARK: - Deletion

    /// Remove every target. When `toTrash` is true items are moved to the bin
    /// (recoverable) instead of being unlinked. Returns bytes actually removed.
    @discardableResult
    nonisolated static func remove(_ targets: [URL], toTrash: Bool) -> Int64 {
        var reclaimed: Int64 = 0
        for url in targets {
            let itemSize = size(of: url)
            do {
                if toTrash {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try fm.removeItem(at: url)
                }
                reclaimed += itemSize
            } catch {
                // Best-effort: skip locked / permission-denied items and keep going.
                continue
            }
        }
        return reclaimed
    }

    // MARK: - Large files

    /// Find regular files under `root` larger than `minSize`. `cancel` is polled
    /// so a long scan can be aborted from the UI.
    nonisolated static func largeFiles(
        under root: URL,
        minSize: Int64,
        limit: Int = 500,
        cancel: () -> Bool = { false }
    ) -> [LargeFile] {
        var results: [LargeFile] = []
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey, .contentModificationDateKey
        ]
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return [] }

        for case let url as URL in enumerator {
            if cancel() { break }
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.isRegularFile == true else { continue }
            let sz = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
            guard sz >= minSize else { continue }
            results.append(LargeFile(
                url: url,
                size: sz,
                modified: v.contentModificationDate ?? .distantPast
            ))
        }

        return Array(results.sorted { $0.size > $1.size }.prefix(limit))
    }
}
