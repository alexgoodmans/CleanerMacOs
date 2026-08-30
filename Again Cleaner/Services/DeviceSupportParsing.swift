//
//  DeviceSupportParsing.swift
//  Again Cleaner
//
//  Pure, testable parsing/classification for Xcode DeviceSupport folder names
//  like "iPhone17,2 27.0 (24A5390f)" or "16.4 (20E247)". Detects duplicate
//  builds (same device + OS version) and marks the older ones — but never
//  decides to delete; the scanner surfaces them for the user to choose.
//

import Foundation

enum DeviceSupportParsing {

    struct Info: Equatable, Sendable {
        let device: String?     // "iPhone17,2" or nil (older layout)
        let version: String     // "27.0"
        let build: String?      // "24A5390f"
        let raw: String
    }

    /// Parse one DeviceSupport folder name.
    nonisolated static func parse(_ name: String) -> Info {
        var device: String?
        var build: String?

        // Build id in trailing parentheses: "… (24A5390f)".
        if let open = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"),
           open < close {
            build = String(name[name.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
        }

        // Strip the "(build)" part, then split the remainder.
        let head = name.prefix(while: { $0 != "(" }).trimmingCharacters(in: .whitespaces)
        let tokens = head.split(separator: " ").map(String.init)

        var version = head
        if let first = tokens.first {
            // A device model looks like "iPhone17,2" / "iPad13,1" / "Watch7,1".
            if first.contains(",") || first.rangeOfCharacter(from: .letters) != nil,
               first.rangeOfCharacter(from: .decimalDigits) != nil,
               tokens.count >= 2 {
                device = first
                version = tokens[1]
            } else {
                version = first
            }
        }
        return Info(device: device, version: version, build: build, raw: name)
    }

    struct Classified: Equatable, Sendable {
        let info: Info
        let isDuplicate: Bool   // another folder has same device+version
        let isOld: Bool         // a newer build of the same device+version exists
    }

    /// Group by device+version; when a group has more than one build, the
    /// highest build stays current and the rest are flagged old duplicates.
    nonisolated static func classify(_ names: [String]) -> [Classified] {
        let infos = names.map(parse)
        // Key that treats nil device as "".
        func key(_ i: Info) -> String { "\(i.device ?? "")|\(i.version)" }

        var groups: [String: [Info]] = [:]
        for i in infos { groups[key(i), default: []].append(i) }

        return infos.map { i in
            let group = groups[key(i)] ?? [i]
            let isDup = group.count > 1
            guard isDup else { return Classified(info: i, isDuplicate: false, isOld: false) }
            // Newest build in the group by build string; nil builds sort lowest.
            let newest = group.max { ($0.build ?? "") < ($1.build ?? "") }
            let isOld = (i.build ?? "") != (newest?.build ?? "")
            return Classified(info: i, isDuplicate: true, isOld: isOld)
        }
    }
}
