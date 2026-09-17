//
//  DiskUsageService.swift
//  Again Cleaner
//
//  One place that measures directory sizes correctly and cancellably. Uses
//  allocated size (blocks actually on disk) so the numbers match what a delete
//  will really free, and skips symlinks so hard/soft links aren't double-counted.
//

import Foundation

/// One immediate child in a Deep Disk tree level.
nonisolated struct DiskChild: Identifiable, Sendable {
    var id: String { url.path }
    let url: URL
    let size: Int64
    let isDirectory: Bool
    let modified: Date?
}

actor DiskUsageService {

    private let fm = FileManager.default

    /// Allocated size of everything under `url`. Polls `isCancelled` so a long
    /// scan can be aborted from the UI. Directories that deny access are skipped.
    ///
    /// When `stayOnVolume` is true the walk behaves like `du -x`: it never
    /// crosses into another mounted volume. This is essential under `/`, where
    /// APFS firmlinks `/System/Volumes/Data` back in — counting across the
    /// boundary would double-count the Data volume as "System".
    func size(
        of url: URL,
        stayOnVolume: Bool = false,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return Self.allocatedSize(of: url) }

        let rootVolume: (any NSObjectProtocol)? = stayOnVolume ? Self.volumeID(of: url) : nil

        let keys: [URLResourceKey] = [
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey, .volumeIdentifierKey,
        ]
        guard let e = fm.enumerator(
            at: url, includingPropertiesForKeys: keys,
            options: [], errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var counter = 0
        for case let file as URL in e {
            counter += 1
            if counter & 0x3FF == 0, isCancelled() { break }   // check every 1024 items

            let meta = try? file.resourceValues(forKeys: [
                .volumeIdentifierKey, .isDirectoryKey, .isSymbolicLinkKey,
            ])
            if meta?.isSymbolicLink == true {
                if meta?.isDirectory == true { e.skipDescendants() }
                continue
            }

            if let rootVolume,
               let vol = meta?.volumeIdentifier, !rootVolume.isEqual(vol) {
                // Different volume: don't count it, and don't descend into it.
                if meta?.isDirectory == true { e.skipDescendants() }
                continue
            }
            total += Self.allocatedSize(of: file)
        }
        return total
    }

    /// Depth-1 listing of `dir` (like `du -xhd 1`): each immediate child with
    /// its recursive allocated size, computed concurrently. Sorted largest first.
    func children(
        of dir: URL,
        stayOnVolume: Bool = false,
        isCancelled: @Sendable () -> Bool = { false }
    ) async -> [DiskChild] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let entries = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return [] }

        var out: [DiskChild] = []
        for child in entries {
            if isCancelled() { break }
            let rv = try? child.resourceValues(forKeys: Set(keys))
            if rv?.isSymbolicLink == true { continue }
            let isDir = rv?.isDirectory ?? false
            let size = size(of: child, stayOnVolume: stayOnVolume, isCancelled: isCancelled)
            if size > 0 {
                out.append(DiskChild(url: child, size: size, isDirectory: isDir,
                                     modified: rv?.contentModificationDate))
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    private nonisolated static func volumeID(of url: URL) -> (any NSObjectProtocol)? {
        try? url.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
    }

    private nonisolated static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .isRegularFileKey, .isSymbolicLinkKey,
        ]
        guard let v = try? url.resourceValues(forKeys: keys) else { return 0 }
        if v.isSymbolicLink == true { return 0 }
        if v.isRegularFile == false { return 0 }
        return Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
    }
}
