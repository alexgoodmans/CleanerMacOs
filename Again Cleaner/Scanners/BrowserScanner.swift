//
//  BrowserScanner.swift
//  Again Cleaner
//
//  Chromium-family browsers (Chrome, Brave, Edge, Vivaldi, Arc, Opera…) store
//  throwaway caches AND real site data under one profile. This scanner splits
//  them: caches are Regeneratable, while IndexedDB is broken down PER DOMAIN and
//  Service Worker / File System / Local Storage stay Review Required — so you
//  can see which site ate the space without wiping logins.
//

import Foundation

nonisolated struct BrowserScanner: CleanupScanner {
    let id = "browsers"
    let displayName = "Browser Site Data"

    private struct Browser {
        let name: String
        let appSupportRel: String   // under ~/Library/Application Support
        let cachesRel: String       // under ~/Library/Caches
    }

    private nonisolated static let browsers: [Browser] = [
        .init(name: "Chrome", appSupportRel: "Google/Chrome", cachesRel: "Google/Chrome"),
        .init(name: "Chrome Canary", appSupportRel: "Google/Chrome Canary", cachesRel: "Google/Chrome Canary"),
        .init(name: "Chromium", appSupportRel: "Chromium", cachesRel: "Chromium"),
        .init(name: "Brave", appSupportRel: "BraveSoftware/Brave-Browser", cachesRel: "BraveSoftware/Brave-Browser"),
        .init(name: "Edge", appSupportRel: "Microsoft Edge", cachesRel: "Microsoft Edge"),
        .init(name: "Vivaldi", appSupportRel: "Vivaldi", cachesRel: "Vivaldi"),
        .init(name: "Arc", appSupportRel: "Arc", cachesRel: "Arc"),
        .init(name: "Opera", appSupportRel: "com.operasoftware.Opera", cachesRel: "com.operasoftware.Opera"),
    ]

    private nonisolated static func appSupport() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support")
    }
    private nonisolated static func caches() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
    }

    nonisolated var ownedPrefixes: [URL] {
        Self.browsers.flatMap {
            [Self.appSupport().appendingPathComponent($0.appSupportRel),
             Self.caches().appendingPathComponent($0.cachesRel)]
        }
    }

    func isAvailable() -> Bool {
        let fm = FileManager.default
        return Self.browsers.contains {
            fm.fileExists(atPath: Self.appSupport().appendingPathComponent($0.appSupportRel).path)
        }
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let fm = FileManager.default
        var out: [CleanupCandidate] = []

        for browser in Self.browsers {
            if ctx.isCancelled() { break }
            let root = Self.appSupport().appendingPathComponent(browser.appSupportRel)
            guard fm.fileExists(atPath: root.path) else { continue }

            // Whole HTTP cache dir (~/Library/Caches/<vendor>).
            let cacheDir = Self.caches().appendingPathComponent(browser.cachesRel)
            if let c = await candidate(cacheDir, scannerID: "browser:\(browser.name):httpcache",
                name: "\(browser.name) HTTP cache", risk: .regeneratable,
                explanation: String(localized: "\(browser.name)'s on-disk web cache."),
                consequence: String(localized: "Cleared; pages re-download as you browse."),
                ctx: ctx) { out.append(c) }

            // Per profile.
            let entries = (try? fm.contentsOfDirectory(at: root,
                includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            for profile in entries where Self.isProfile(profile.lastPathComponent) {
                if ctx.isCancelled() { break }
                out += await scanProfile(profile, browser: browser, ctx: ctx)
            }
        }
        return out
    }

    private static func isProfile(_ name: String) -> Bool {
        name == "Default" || name == "Guest Profile" || name.hasPrefix("Profile ")
    }

    private func scanProfile(_ profile: URL, browser: Browser, ctx: ScanContext) async -> [CleanupCandidate] {
        let fm = FileManager.default
        let tag = "\(browser.name) (\(profile.lastPathComponent))"
        var out: [CleanupCandidate] = []

        // Cache-family subfolders → regeneratable.
        for sub in ChromiumStorage.cacheSubdirs {
            if let c = await candidate(profile.appendingPathComponent(sub),
                scannerID: "browser:\(tag):cache:\(sub)",
                name: "\(tag) · \(sub)", risk: .regeneratable,
                explanation: String(localized: "\(browser.name) cache data."),
                consequence: String(localized: "Cleared; regenerated automatically."),
                ctx: ctx) { out.append(c) }
        }

        // IndexedDB broken down per origin (the "site data by domain" feature).
        let idb = profile.appendingPathComponent("IndexedDB")
        if let folders = try? fm.contentsOfDirectory(at: idb,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            var byOrigin: [String: Int64] = [:]
            for folder in folders {
                if ctx.isCancelled() { break }
                guard let origin = ChromiumStorage.origin(fromIndexedDBFolder: folder.lastPathComponent) else { continue }
                let size = await ctx.usage.size(of: folder, isCancelled: ctx.isCancelled)
                byOrigin[origin, default: 0] += size
            }
            for (origin, size) in byOrigin where size > 0 {
                out.append(CleanupCandidate(
                    scannerID: "browser:\(tag):idb:\(origin)",
                    name: "\(origin) — site data",
                    path: idb, size: size, risk: .reviewRequired,
                    explanation: String(localized: "\(browser.name) IndexedDB storage for \(origin)."),
                    consequence: String(localized: "Removing clears this site's offline data in \(browser.name)."),
                    method: .filesystem
                ))
            }
        }

        // Other storage families → aggregate per profile, Review Required.
        for sub in ChromiumStorage.storageSubdirs {
            if let c = await candidate(profile.appendingPathComponent(sub),
                scannerID: "browser:\(tag):storage:\(sub)",
                name: "\(tag) · \(sub)", risk: .reviewRequired,
                explanation: String(localized: "\(browser.name) \(sub) across all sites."),
                consequence: String(localized: "Review — removing affects site sessions/offline data."),
                ctx: ctx) { out.append(c) }
        }
        return out
    }

    private func candidate(_ url: URL, scannerID: String, name: String, risk: CleanupRisk,
                           explanation: String, consequence: String,
                           ctx: ScanContext) async -> CleanupCandidate? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = await ctx.usage.size(of: url, isCancelled: ctx.isCancelled)
        guard size > 0 else { return nil }
        return CleanupCandidate(
            scannerID: scannerID, name: name, path: url, size: size, risk: risk,
            explanation: explanation, consequence: consequence, method: .filesystem)
    }
}
