//
//  LeftoverMatching.swift
//  Again Cleaner
//
//  Pure, testable rules for recognising orphaned app data. The golden rule
//  (from the audit): NEVER match on a name substring. We only treat an item as
//  a leftover when its name is an exact bundle identifier (reverse-DNS) whose
//  owning app is not installed — and never a system/Apple id.
//

import Foundation

enum LeftoverMatching {

    /// A reverse-DNS bundle id: at least two dot-separated segments of
    /// url-safe characters, e.g. "com.google.Chrome".
    nonisolated static func isBundleIdentifier(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return parts.allSatisfy { part in
            !part.isEmpty && String(part).unicodeScalars.allSatisfy { allowed.contains($0) }
        }
    }

    /// Strip a known metadata extension to recover the bundle id from a file
    /// name: "com.foo.Bar.plist" → "com.foo.Bar".
    nonisolated static func bundleID(fromFileName name: String) -> String {
        for ext in [".plist", ".savedState", ".binarycookies"] where name.hasSuffix(ext) {
            return String(name.dropLast(ext.count))
        }
        return name
    }

    /// System / Apple / framework ids we must never treat as a removable
    /// leftover even when no matching .app exists.
    nonisolated static func isSystem(_ id: String) -> Bool {
        let lower = id.lowercased()
        let prefixes = [
            "com.apple.", "group.com.apple.", "com.apple",
            "systemgroup.", "group.com.apple", "apple.",
        ]
        return prefixes.contains { lower.hasPrefix($0) }
    }

    /// Is `id` an orphan? A bundle-id-shaped, non-system name not present in the
    /// installed set (compared case-insensitively).
    nonisolated static func isOrphan(_ id: String, installed: Set<String>) -> Bool {
        guard isBundleIdentifier(id), !isSystem(id) else { return false }
        return !installed.contains(id.lowercased())
    }
}
