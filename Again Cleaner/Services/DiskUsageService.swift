//
//  DiskUsageService.swift
//  Again Cleaner
//
//  One place that measures directory sizes correctly and cancellably. Uses
//  allocated size (blocks actually on disk) so the numbers match what a delete
//  will really free, and skips symlinks so hard/soft links aren't double-counted.
//

import Foundation

actor DiskUsageService {

    private let fm = FileManager.default

    /// Allocated size of everything under `url`. Polls `isCancelled` so a long
    /// scan can be aborted from the UI. Directories that deny access are skipped.
    func size(of url: URL, isCancelled: @Sendable () -> Bool = { false }) -> Int64 {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return Self.allocatedSize(of: url) }

        let keys: [URLResourceKey] = [
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .isRegularFileKey, .isSymbolicLinkKey,
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
            total += Self.allocatedSize(of: file)
        }
        return total
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
