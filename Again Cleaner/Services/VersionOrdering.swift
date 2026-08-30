//
//  VersionOrdering.swift
//  Again Cleaner
//
//  Semantic-ish version comparison used to tell an old SDK version from the
//  current one (Arduino cores, etc.). Purely lexical/numeric — no deletion
//  decisions live here.
//

import Foundation

enum VersionOrdering {

    /// Compare two dotted version strings numerically component-by-component,
    /// falling back to string order for non-numeric parts. "3.3.11" > "3.3.2".
    nonisolated static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let lhs = a.split(separator: ".").map(String.init)
        let rhs = b.split(separator: ".").map(String.init)
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : ""
            let r = i < rhs.count ? rhs[i] : ""
            if let ln = Int(l), let rn = Int(r) {
                if ln != rn { return ln < rn ? .orderedAscending : .orderedDescending }
            } else if l != r {
                return l < r ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    /// The newest version in a list.
    nonisolated static func newest(_ versions: [String]) -> String? {
        versions.max { compare($0, $1) == .orderedAscending }
    }

    /// Every version except the newest — candidates to flag as "old".
    nonisolated static func olderThanNewest(_ versions: [String]) -> Set<String> {
        guard let newest = newest(versions) else { return [] }
        return Set(versions.filter { $0 != newest })
    }
}
