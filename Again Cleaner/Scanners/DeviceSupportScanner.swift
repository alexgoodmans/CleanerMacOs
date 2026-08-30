//
//  DeviceSupportScanner.swift
//  Again Cleaner
//
//  Breaks Xcode DeviceSupport into per-version rows (device / OS / build /
//  size), flags duplicate builds and old versions — but keeps everything
//  Review Required. Xcode regenerates DeviceSupport when you next connect a
//  device on that OS, yet deleting the wrong one costs a slow re-copy, so it
//  is never auto-selected.
//

import Foundation

nonisolated struct DeviceSupportScanner: CleanupScanner {
    let id = "device-support"
    let displayName = "Xcode DeviceSupport"

    private nonisolated static let relRoots = [
        "Library/Developer/Xcode/iOS DeviceSupport",
        "Library/Developer/Xcode/watchOS DeviceSupport",
        "Library/Developer/Xcode/tvOS DeviceSupport",
        "Library/Developer/Xcode/visionOS DeviceSupport",
    ]

    private nonisolated static func roots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return relRoots.map { home.appendingPathComponent($0) }
    }

    nonisolated var ownedPrefixes: [URL] { Self.roots() }

    func isAvailable() -> Bool {
        Self.roots().contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let fm = FileManager.default
        var out: [CleanupCandidate] = []

        for root in Self.roots() {
            if ctx.isCancelled() { break }
            let entries = (try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])) ?? []
            guard !entries.isEmpty else { continue }

            let classified = DeviceSupportParsing.classify(entries.map(\.lastPathComponent))
            let byName = Dictionary(uniqueKeysWithValues: classified.map { ($0.info.raw, $0) })

            for url in entries {
                if ctx.isCancelled() { break }
                let size = await ctx.usage.size(of: url, isCancelled: ctx.isCancelled)
                guard size > 0 else { continue }
                let c = byName[url.lastPathComponent]

                var note = ""
                if c?.isOld == true { note = String(localized: "Old DeviceSupport — a newer build exists.") }
                else if c?.isDuplicate == true { note = String(localized: "Possible duplicate DeviceSupport.") }

                let info = c?.info
                let title = [info?.device, info?.version.isEmpty == false ? info?.version : nil]
                    .compactMap { $0 }.joined(separator: " ")
                let name = title.isEmpty ? url.lastPathComponent : title
                    + (info?.build.map { " (\($0))" } ?? "")

                out.append(CleanupCandidate(
                    scannerID: "device-support:\(url.lastPathComponent)",
                    name: name,
                    path: url, size: size, risk: .reviewRequired,
                    explanation: String(localized: "Debug symbols Xcode copied from a device on this OS. \(note)"),
                    consequence: String(localized: "Xcode re-copies them next time you debug on that OS version."),
                    lastModified: try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                    method: .filesystem
                ))
            }
        }
        return out
    }
}
