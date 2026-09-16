//
//  ScannerSupport.swift
//  Again Cleaner
//
//  Shared filesystem helpers for scanners: listing that never follows
//  directory symlinks, modification dates, and a small candidate factory.
//

import Foundation

enum DirListing {

    /// Immediate children. Directory symlinks are skipped (never followed).
    nonisolated static func children(
        of dir: URL,
        dirsOnly: Bool = false,
        skipHidden: Bool = true
    ) -> [URL] {
        var opts: FileManager.DirectoryEnumerationOptions = []
        if skipHidden { opts.insert(.skipsHiddenFiles) }
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: opts
        )) ?? []
        return items.filter { url in
            let v = try? url.resourceValues(forKeys: Set(keys))
            if v?.isSymbolicLink == true { return false }
            if dirsOnly && v?.isDirectory != true { return false }
            return true
        }
    }

    nonisolated static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    nonisolated static func isReadable(_ url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    nonisolated static func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    nonisolated static func accessed(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate
    }

    nonisolated static func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    nonisolated static func bytes(_ value: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return value <= 0 ? "—" : f.string(fromByteCount: value)
    }

    /// Newest and oldest modification dates among immediate children.
    nonisolated static func dateRange(of dir: URL) -> (oldest: Date?, newest: Date?) {
        let kids = children(of: dir, skipHidden: false)
        let dates = kids.compactMap(modified)
        return (dates.min(), dates.max())
    }

    nonisolated static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
}

enum IgnoreStore {
    nonisolated static let key = "ignoredCleanupPaths"

    nonisolated static func paths() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    nonisolated static func contains(_ url: URL) -> Bool {
        paths().contains(PathGuard.canonicalPath(url))
    }

    nonisolated static func ignore(_ url: URL) {
        var set = paths()
        set.insert(PathGuard.canonicalPath(url))
        UserDefaults.standard.set(Array(set), forKey: key)
    }

    nonisolated static func unignore(_ url: URL) {
        var set = paths()
        set.remove(PathGuard.canonicalPath(url))
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}

extension ScanContext {
    /// Measure a path, returning nil when empty or cancelled.
    func measured(_ url: URL) async -> Int64? {
        guard DirListing.exists(url) else { return nil }
        let size = await usage.size(of: url, isCancelled: isCancelled)
        if isCancelled() { return nil }
        return size > 0 ? size : nil
    }

    func candidate(
        scannerID: String,
        name: String,
        url: URL,
        risk: CleanupRisk,
        explanation: String,
        consequence: String,
        category: ScanCategory? = nil,
        subcategory: String? = nil,
        developer: String? = nil,
        confidence: ScanConfidence = .high,
        method: CleanupMethod = .filesystem,
        requiresAdmin: Bool = false
    ) async -> CleanupCandidate? {
        guard let size = await measured(url) else { return nil }
        return CleanupCandidate(
            scannerID: scannerID,
            name: name,
            path: url,
            size: size,
            risk: risk,
            category: category,
            subcategory: subcategory,
            developer: developer,
            confidence: confidence,
            requiresAdmin: requiresAdmin,
            explanation: explanation,
            consequence: consequence,
            lastModified: DirListing.modified(url),
            lastAccessed: DirListing.accessed(url),
            method: method
        )
    }
}
