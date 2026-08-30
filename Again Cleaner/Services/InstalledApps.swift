//
//  InstalledApps.swift
//  Again Cleaner
//
//  Collects the bundle identifiers of every installed app so the leftover
//  scanner can tell orphaned data from data belonging to a live app.
//

import Foundation

enum InstalledApps {

    private nonisolated static func roots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            "/Applications", "/Applications/Utilities",
            "/System/Applications", "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            home.appendingPathComponent("Applications").path,
        ].map { URL(fileURLWithPath: $0) }
    }

    /// Lowercased bundle identifiers of all installed apps.
    nonisolated static func bundleIDs() -> Set<String> {
        let fm = FileManager.default
        var ids: Set<String> = []
        for root in roots() {
            let apps = (try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for app in apps where app.pathExtension == "app" {
                if let id = Bundle(url: app)?.bundleIdentifier {
                    ids.insert(id.lowercased())
                }
            }
        }
        return ids
    }
}
