//
//  EditorExtensionParsing.swift
//  Again Cleaner
//
//  Parse VS Code / Cursor extension folder names (`publisher.name-1.2.3`) and
//  group them into current vs stale versions. Semantic comparison, not lexical.
//

import Foundation

enum EditorExtensionParsing {

    struct Parsed: Equatable, Sendable {
        let extensionID: String
        let version: String
        let folderName: String
    }

    struct Group: Equatable, Sendable {
        let extensionID: String
        let newest: Parsed
        let stale: [Parsed]
        var installedCount: Int { 1 + stale.count }
    }

    /// `publisher.name-1.2.3` or `publisher.name-1.2.3-universal`.
    nonisolated static func parse(_ folderName: String) -> Parsed? {
        guard let dot = folderName.firstIndex(of: ".") else { return nil }
        var i = folderName.index(after: dot)
        while i < folderName.endIndex {
            if folderName[i] == "-" {
                let next = folderName.index(after: i)
                if next < folderName.endIndex, folderName[next].isNumber {
                    let id = String(folderName[..<i])
                    let version = String(folderName[next...])
                    guard id.contains(".") else { return nil }
                    return Parsed(extensionID: id, version: version, folderName: folderName)
                }
            }
            folderName.formIndex(after: &i)
        }
        return nil
    }

    /// Numeric version for comparison, stripping suffixes like `-universal`.
    nonisolated static func versionCore(_ version: String) -> String {
        let core = version.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first
        return String(core ?? Substring(version))
    }

    nonisolated static func groups(from folderNames: [String]) -> [Group] {
        var buckets: [String: [Parsed]] = [:]
        for name in folderNames {
            guard let parsed = parse(name) else { continue }
            buckets[parsed.extensionID, default: []].append(parsed)
        }
        return buckets.values.compactMap { versions in
            guard let newest = versions.max(by: {
                VersionOrdering.compare(versionCore($0.version), versionCore($1.version)) == .orderedAscending
            }) else { return nil }
            let stale = versions.filter { $0.folderName != newest.folderName }
            return Group(extensionID: newest.extensionID, newest: newest, stale: stale)
        }
        .sorted { $0.extensionID < $1.extensionID }
    }
}
