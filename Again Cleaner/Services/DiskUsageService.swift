//
//  DiskUsageService.swift
//  Again Cleaner
//
//  One place that measures directory sizes correctly and cancellably. Uses
//  allocated size (blocks actually on disk) so the numbers match what a delete
//  will really free, never follows symlinks, and counts hard links once.
//
//  The walk uses fts(3) — the same traversal `du` uses — reading st_blocks
//  straight from each entry's stat. A FileManager enumerator with per-file
//  resource lookups was measured at 25×+ slower (~/Library: >10 min vs 23 s
//  for `du`), which made Deep Disk Scan look broken on real home folders.
//

import Foundation
import Darwin

/// One immediate child in a Deep Disk tree level.
nonisolated struct DiskChild: Identifiable, Sendable {
    var id: String { url.path }
    let url: URL
    let size: Int64
    let isDirectory: Bool
    let modified: Date?
    /// A cloud-sync root (OneDrive, iCloud Drive…) that is listed but never walked.
    var isCloud = false
    /// A separate APFS volume (VM, Preboot…) sized from statfs, not walked.
    var isVolume = false
}

actor DiskUsageService {

    /// Allocated size of everything under `url`. Polls `isCancelled` so a long
    /// scan can be aborted from the UI. Unreadable directories are skipped.
    /// (Scanners call this; being an actor keeps their I/O serialized.)
    func size(of url: URL, isCancelled: @Sendable () -> Bool = { false }) -> Int64 {
        Self.measure(url, isCancelled: isCancelled)
    }

    // MARK: - Cloud storage

    /// Cloud-sync roots that are never walked. Their folders are served by File
    /// Provider extensions (OneDrive, Google Drive, Dropbox…) or iCloud Drive:
    /// reading a directory there blocks until the provider answers — observed
    /// hanging forever in getattrlistbulk on OneDrive — and can trigger
    /// downloads. Most of their content is cloud-only anyway.
    nonisolated static var cloudRoots: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Library/CloudStorage", "Library/Mobile Documents"].map {
            PathGuard.canonicalPath(home.appendingPathComponent($0))
        }
    }

    nonisolated static func isCloudStorage(_ url: URL) -> Bool {
        isUnder(PathGuard.canonicalPath(url), cloudRoots)
    }

    private nonisolated static func isUnder(_ path: String, _ roots: [String]) -> Bool {
        roots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    // MARK: - Fast measuring

    private struct Inode: Hashable {
        let dev: Int32
        let ino: UInt64
    }

    /// Allocated bytes under `url` (a file or a directory), never descending
    /// into any path equal to or under one of `excluded`.
    ///
    /// - Counts regular files only (like Finder's "size on disk").
    /// - `FTS_PHYSICAL`: symlinks are not followed, so nothing is reached twice.
    /// - `FTS_NOCHDIR`: no process-wide chdir, so several walks can run in
    ///   parallel safely.
    /// - Hard-linked files (`st_nlink > 1`) are counted once per walk.
    /// - Cloud-sync roots (`cloudRoots`) are always skipped — see above.
    ///
    /// Static and synchronous so Deep Disk can measure several children in
    /// parallel off the main actor.
    nonisolated static func measure(
        _ url: URL,
        excluding extraExcluded: [String] = [],
        isCancelled: () -> Bool = { false }
    ) -> Int64 {
        let cloud = cloudRoots
        if isUnder(PathGuard.canonicalPath(url), cloud) { return 0 }
        let excluded = extraExcluded + cloud

        guard let root = strdup(url.path) else { return 0 }
        defer { free(root) }
        var argv: [UnsafeMutablePointer<CChar>?] = [root, nil]
        guard let fts = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR, nil) else { return 0 }
        defer { fts_close(fts) }

        var total: Int64 = 0
        var linked = Set<Inode>()
        var visited = 0

        while let entry = fts_read(fts) {
            visited += 1
            if visited & 0x3FF == 0, isCancelled() { break }

            switch Int32(entry.pointee.fts_info) {
            case FTS_D:
                // fts reports the path as reached (e.g. /Users/x/Library/…),
                // which matches the canonical cloud roots for home paths.
                if isUnder(String(cString: entry.pointee.fts_path), excluded) {
                    fts_set(fts, entry, FTS_SKIP)
                }
            case FTS_F:
                guard let st = entry.pointee.fts_statp?.pointee else { continue }
                if st.st_nlink > 1,
                   !linked.insert(Inode(dev: st.st_dev, ino: st.st_ino)).inserted {
                    continue
                }
                total += Int64(st.st_blocks) * 512
            default:
                continue   // symlinks, unreadable dirs, post-order dirs, errors
            }
        }
        return total
    }

    // MARK: - Deep Disk listing

    /// One immediate child of a directory, before its size is known.
    nonisolated struct Entry: Sendable {
        let url: URL
        let isDirectory: Bool
        let modified: Date?
        let isCloud: Bool
        /// Set for APFS service volumes: their used size, known without walking.
        var volumeUsage: Int64? = nil
    }

    /// APFS volumes that share the boot container with System and Data and
    /// really consume its space, but live under the excluded /System/Volumes.
    /// VM holds swap + the sleep image and is routinely tens of GB.
    nonisolated static let serviceVolumes = ["VM", "Preboot", "Update", "Recovery"]

    /// Used bytes of the volume mounted exactly at `path` (what `df` reports),
    /// or nil when nothing is mounted there.
    ///
    /// For APFS, statfs' f_blocks − f_bfree is the whole CONTAINER's usage
    /// (identical for every volume), so the per-volume figure comes from
    /// getattrlist(ATTR_VOL_SPACEUSED) — the same source `df` uses.
    nonisolated static func volumeUsage(mountedAt path: String) -> Int64? {
        var fs = statfs()
        guard statfs(path, &fs) == 0 else { return nil }
        let mountedOn = withUnsafeBytes(of: fs.f_mntonname) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        // Not a mount point → statfs answered for the parent volume; skip it.
        guard mountedOn == path else { return nil }

        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.volattr = attrgroup_t(ATTR_VOL_INFO) | attrgroup_t(ATTR_VOL_SPACEUSED)
        // Reply layout: u_int32_t length, then off_t space-used (4-byte packed).
        var reply = [UInt8](repeating: 0, count: 16)
        let rc = reply.withUnsafeMutableBytes { buf in
            getattrlist(path, &request, buf.baseAddress, buf.count, 0)
        }
        guard rc == 0 else { return nil }
        let used = reply.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: Int64.self) }
        return used > 0 ? used : nil
    }

    /// Never descended into when measuring the volume root `/`.
    ///
    /// On APFS `/` is the sealed System volume, while `/Users`, `/Applications`,
    /// `/Library`, `/private`, `/opt`… are firmlinks into the Data volume, which
    /// is ALSO mounted at `/System/Volumes/Data` (same inodes). Measuring the
    /// firmlinks and skipping `/System/Volumes` counts the Data volume exactly
    /// once. `/Volumes` holds other mounted disks; `/dev` etc. aren't storage.
    nonisolated static let volumeRootExclusions = ["/System/Volumes", "/Volumes", "/dev", "/net", "/home"]

    /// Depth-1 listing of `dir`, returned immediately (no sizing). Hidden items
    /// ARE included — `~/Library` and dot-folders (`~/.gradle`, `~/.docker`…)
    /// are often the biggest consumers. Symlinks are skipped (no double count);
    /// at `/` the volume plumbing (`/Volumes`, `/dev`, `.vol`…) is left out.
    nonisolated static func listing(of dir: URL) -> [Entry] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: []
        ) else { return [] }

        let isVolumeRoot = PathGuard.canonicalPath(dir) == "/"
        var entries: [Entry] = items.compactMap { url in
            let name = url.lastPathComponent
            if name == ".DS_Store" || name == ".localized" { return nil }
            if isVolumeRoot && (name.hasPrefix(".") || name == "Volumes" || name == "dev") { return nil }
            let rv = try? url.resourceValues(forKeys: Set(keys))
            if rv?.isSymbolicLink == true { return nil }
            return Entry(url: url, isDirectory: rv?.isDirectory ?? false,
                         modified: rv?.contentModificationDate,
                         isCloud: isCloudStorage(url))
        }

        // At `/`, also surface the container's service volumes — they're
        // excluded from the walk (under /System/Volumes) yet use real space.
        if isVolumeRoot {
            for name in serviceVolumes {
                let path = "/System/Volumes/" + name
                guard let used = volumeUsage(mountedAt: path), used >= 100_000_000 else { continue }
                entries.append(Entry(url: URL(fileURLWithPath: path), isDirectory: true,
                                     modified: nil, isCloud: false, volumeUsage: used))
            }
        }
        return entries
    }
}
