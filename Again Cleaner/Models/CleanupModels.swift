//
//  CleanupModels.swift
//  Again Cleaner
//
//  Core data models for junk categories and large files.
//

import Foundation

/// How dangerous a category is to clean. Drives colour + default selection.
enum Safety: Int, Comparable, Codable {
    case safe       // caches, logs, trash — always fine to remove
    case caution    // package-manager caches, DerivedData — regenerated on demand
    case risky      // simulators, whole app-support folders — needs re-download / thought

    static func < (lhs: Safety, rhs: Safety) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .safe:    return String(localized: "Safe")
        case .caution: return String(localized: "Caution")
        case .risky:   return String(localized: "Risky")
        }
    }
}

/// Describes *what* a category removes. Kept declarative so the UI never
/// has to know how a category is cleaned.
enum CleanRule: Sendable {
    /// Remove the children of these directories but keep the directory itself.
    /// (e.g. ~/Library/Caches — the folder must survive.)
    case clearContents([URL])

    /// Remove these paths entirely (files or directories).
    case removePaths([URL])

    /// Recursively find directories named `names` under `root` and remove them.
    /// (e.g. every `node_modules` under ~/Projects.)
    case findDirs(root: URL, names: [String])

    /// Remove the *top-level* items directly inside `dir` that haven't been
    /// modified in the last `days` days. Used for user folders (Downloads,
    /// Desktop) where only stale files should ever be suggested.
    case oldItems(dir: URL, days: Int)

    /// The folder(s) that represent this rule when the user pins it to
    /// Favorites for one-click cleanup later.
    var favoritableURLs: [URL] {
        switch self {
        case .clearContents(let dirs):  return dirs
        case .removePaths(let paths):   return paths
        case .findDirs(let root, _):    return [root]
        case .oldItems(let dir, _):     return [dir]
        }
    }
}

/// A group of junk that can be scanned and cleaned as a unit.
struct JunkCategory: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let safety: Safety
    let rule: CleanRule
}

/// Result of measuring a single category on disk.
struct CategoryScanResult: Identifiable {
    let id: String
    var size: Int64            // reclaimable bytes
    var itemCount: Int         // number of top-level items that would be removed
    var isScanning: Bool
}

/// One concrete item that a category would remove — shown when a row is
/// expanded so the user can see exactly what will go.
struct TargetItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let isDirectory: Bool
    var name: String { url.lastPathComponent }
    var path: String { url.path }
    var parentPath: String { url.deletingLastPathComponent().path }
}

/// A user-picked directory saved for one-click cleanup.
struct FavoriteFolder: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    var size: Int64 = 0
    var isScanning: Bool = false
    var name: String { url.lastPathComponent }
    var path: String { url.path }
}

/// A single large file discovered on disk.
struct LargeFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let modified: Date

    var name: String { url.lastPathComponent }
    var path: String { url.path }
}

/// Snapshot of the boot volume's capacity.
struct DiskInfo {
    var total: Int64
    var free: Int64
    var used: Int64 { total - free }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}
