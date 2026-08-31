//
//  ChromiumStorage.swift
//  Again Cleaner
//
//  Pure, testable helpers for Chromium-family browser storage. The key insight
//  from the real layout: IndexedDB folders are named after their origin
//  ("https_www.reddit.com_0.indexeddb.leveldb"), so per-domain attribution is
//  plain string parsing — no LevelDB reader required.
//

import Foundation

enum ChromiumStorage {

    /// Recover the host from an IndexedDB folder/file name.
    /// "https_studio.tripo3d.ai_0.indexeddb.leveldb" → "studio.tripo3d.ai".
    /// Returns nil for non-http(s) origins (extensions, filesystem, etc.).
    nonisolated static func origin(fromIndexedDBFolder name: String) -> String? {
        var base = name
        var stripped = false
        for suffix in [".indexeddb.leveldb", ".indexeddb.blob"] where base.hasSuffix(suffix) {
            base = String(base.dropLast(suffix.count)); stripped = true; break
        }
        guard stripped else { return nil }

        let parts = base.split(separator: "_", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3 else { return nil }
        guard parts[0] == "http" || parts[0] == "https" else { return nil }
        let host = parts[1..<(parts.count - 1)].joined(separator: "_")
        return host.isEmpty ? nil : host
    }

    /// Cache-family subfolders — safe to clear, the browser rebuilds them.
    nonisolated static let cacheSubdirs: [String] = [
        "Cache", "Code Cache", "GPUCache", "ShaderCache",
        "GraphiteDawnCache", "DawnWebGPUCache", "GrShaderCache",
    ]

    /// Storage-family subfolders — real site data, Review Required.
    nonisolated static let storageSubdirs: [String] = [
        "Service Worker", "File System", "Local Storage", "Session Storage",
    ]
}
