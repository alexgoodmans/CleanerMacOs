//
//  CleanupCatalog.swift
//  Again Cleaner
//
//  The catalogue of known-safe junk locations on macOS, ordered from the
//  safest (caches/logs/trash) to the heaviest (simulators, dev bundles).
//
//  The list is part curated (well-known tools with a known safety level) and
//  part generated: every remaining folder in ~/Library/Caches becomes its own
//  entry, so caches from less-popular apps are surfaced too. User folders such
//  as Downloads are offered as well, but only their stale contents.
//

import Foundation

enum CleanupCatalog {

    private static let fm = FileManager.default
    private static let home = FileManager.default.homeDirectoryForCurrentUser

    private static func h(_ path: String) -> URL {
        home.appendingPathComponent(path)
    }

    /// Everything the app knows about, in display order.
    static var all: [JunkCategory] {
        curated + otherAppCaches() + userFolders()
    }

    // MARK: - Curated, well-known categories

    private static var curated: [JunkCategory] {
        [
            // ── Always safe ────────────────────────────────────────────────
            JunkCategory(
                id: "user-logs",
                title: String(localized: "Logs"),
                subtitle: String(localized: "~/Library/Logs — diagnostic logs"),
                systemImage: "doc.text.magnifyingglass",
                safety: .safe,
                rule: .clearContents([h("Library/Logs")])
            ),
            JunkCategory(
                id: "trash",
                title: String(localized: "Trash"),
                subtitle: String(localized: "~/.Trash — permanently empty the bin"),
                systemImage: "trash",
                safety: .safe,
                rule: .clearContents([h(".Trash")])
            ),

            // ── Package-manager caches (regenerated on next install) ───────
            JunkCategory(
                id: "homebrew",
                title: String(localized: "Homebrew Cache"),
                subtitle: String(localized: "Downloaded bottles & formulae"),
                systemImage: "mug",
                safety: .caution,
                rule: .clearContents([h("Library/Caches/Homebrew")])
            ),
            JunkCategory(
                id: "yarn",
                title: String(localized: "Yarn Cache"),
                subtitle: String(localized: "~/Library/Caches/Yarn"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h("Library/Caches/Yarn")])
            ),
            JunkCategory(
                id: "npm",
                title: String(localized: "npm Cache"),
                subtitle: String(localized: "~/.npm/_cacache"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h(".npm/_cacache")])
            ),
            JunkCategory(
                id: "pnpm",
                title: String(localized: "pnpm Store"),
                subtitle: String(localized: "~/Library/Caches/pnpm"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h("Library/Caches/pnpm")])
            ),
            JunkCategory(
                id: "pip",
                title: String(localized: "pip Cache"),
                subtitle: String(localized: "~/Library/Caches/pip"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h("Library/Caches/pip")])
            ),
            JunkCategory(
                id: "cocoapods",
                title: String(localized: "CocoaPods Cache"),
                subtitle: String(localized: "~/Library/Caches/CocoaPods"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h("Library/Caches/CocoaPods")])
            ),
            JunkCategory(
                id: "go-build",
                title: String(localized: "Go Build Cache"),
                subtitle: String(localized: "~/Library/Caches/go-build"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h("Library/Caches/go-build")])
            ),
            JunkCategory(
                id: "playwright",
                title: String(localized: "Playwright Browsers"),
                subtitle: String(localized: "~/Library/Caches/ms-playwright"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h("Library/Caches/ms-playwright")])
            ),
            JunkCategory(
                id: "gradle",
                title: String(localized: "Gradle Cache"),
                subtitle: String(localized: "~/.gradle/caches — re-downloaded on next build"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h(".gradle/caches")])
            ),
            JunkCategory(
                id: "espressif",
                title: String(localized: "Espressif Downloads"),
                subtitle: String(localized: "~/.espressif/dist — ESP-IDF installer archives"),
                systemImage: "cpu",
                safety: .caution,
                rule: .removePaths([h(".espressif/dist"),
                                    h(".espressif/tools/.download")])
            ),
            JunkCategory(
                id: "arduino",
                title: String(localized: "Arduino Cache"),
                subtitle: String(localized: "~/Library/Arduino15/cache & staging"),
                systemImage: "cpu",
                safety: .caution,
                rule: .removePaths([h("Library/Arduino15/cache"),
                                    h("Library/Arduino15/staging")])
            ),

            // ── Xcode / iOS development ────────────────────────────────────
            JunkCategory(
                id: "xcode-derived",
                title: String(localized: "Xcode DerivedData"),
                subtitle: String(localized: "Build intermediates — rebuilt on next build"),
                systemImage: "hammer",
                safety: .caution,
                rule: .clearContents([h("Library/Developer/Xcode/DerivedData")])
            ),
            JunkCategory(
                id: "xcode-archives",
                title: String(localized: "Xcode Archives"),
                subtitle: String(localized: "Old app archives — keep if you still ship them"),
                systemImage: "archivebox",
                safety: .risky,
                rule: .clearContents([h("Library/Developer/Xcode/Archives")])
            ),
            JunkCategory(
                id: "xcode-devicesupport",
                title: String(localized: "iOS Device Support"),
                subtitle: String(localized: "Symbols for old iOS versions — re-downloaded on connect"),
                systemImage: "iphone",
                safety: .caution,
                rule: .clearContents([h("Library/Developer/Xcode/iOS DeviceSupport")])
            ),

            // ── Editors ────────────────────────────────────────────────────
            JunkCategory(
                id: "cursor",
                title: String(localized: "Cursor Caches"),
                subtitle: String(localized: "Cache / CachedData / GPUCache / logs"),
                systemImage: "cursorarrow.rays",
                safety: .caution,
                rule: .removePaths([
                    h("Library/Application Support/Cursor/Cache"),
                    h("Library/Application Support/Cursor/CachedData"),
                    h("Library/Application Support/Cursor/GPUCache"),
                    h("Library/Application Support/Cursor/Code Cache"),
                    h("Library/Application Support/Cursor/logs"),
                    h(".cursor/logs")
                ])
            ),
            JunkCategory(
                id: "vscode",
                title: String(localized: "VS Code Caches"),
                subtitle: String(localized: "Cache / CachedData / GPUCache / logs"),
                systemImage: "chevron.left.forwardslash.chevron.right",
                safety: .caution,
                rule: .removePaths([
                    h("Library/Application Support/Code/Cache"),
                    h("Library/Application Support/Code/CachedData"),
                    h("Library/Application Support/Code/GPUCache"),
                    h("Library/Application Support/Code/Code Cache"),
                    h("Library/Application Support/Code/logs")
                ])
            ),

            // ── Heavy: project build artefacts ─────────────────────────────
            JunkCategory(
                id: "node-modules",
                title: String(localized: "node_modules in ~/Projects"),
                subtitle: String(localized: "Every node_modules — restore with `npm install`"),
                systemImage: "folder.badge.gearshape",
                safety: .risky,
                rule: .findDirs(root: h("Projects"),
                                names: ["node_modules"])
            ),
            JunkCategory(
                id: "build-dirs",
                title: String(localized: "Build folders in ~/Projects"),
                subtitle: String(localized: "target / build / .next / dist / .gradle caches"),
                systemImage: "folder.badge.gearshape",
                safety: .risky,
                rule: .findDirs(root: h("Projects"),
                                names: ["target", "build", ".next", "dist"])
            ),
        ]
    }

    // MARK: - Generated: every other app cache

    /// Cache subfolders in ~/Library/Caches that aren't already covered by a
    /// curated entry above. One category per app so anything — even niche
    /// tools — can be found and cleaned.
    private static let curatedCacheNames: Set<String> = [
        "Homebrew", "Yarn", "pnpm", "pip", "CocoaPods", "go-build", "ms-playwright"
    ]

    private static func otherAppCaches() -> [JunkCategory] {
        let cachesDir = h("Library/Caches")
        let children = (try? fm.contentsOfDirectory(
            at: cachesDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return children.compactMap { url -> JunkCategory? in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { return nil }
            let name = url.lastPathComponent
            guard !curatedCacheNames.contains(name) else { return nil }

            return JunkCategory(
                id: "cache:\(name)",
                title: friendlyName(name),
                subtitle: String(localized: "~/Library/Caches/\(name)"),
                systemImage: icon(for: name),
                safety: .caution,
                rule: .removePaths([url])
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Generated: user folders

    private static func userFolders() -> [JunkCategory] {
        [
            JunkCategory(
                id: "downloads-old",
                title: String(localized: "Old Downloads"),
                subtitle: String(localized: "Items in ~/Downloads untouched for 30+ days"),
                systemImage: "arrow.down.circle",
                safety: .risky,
                rule: .oldItems(dir: h("Downloads"), days: 30)
            ),
            JunkCategory(
                id: "desktop-old",
                title: String(localized: "Old Desktop Items"),
                subtitle: String(localized: "Items on the Desktop untouched for 90+ days"),
                systemImage: "menubar.dock.rectangle",
                safety: .risky,
                rule: .oldItems(dir: h("Desktop"), days: 90)
            ),
        ]
    }

    // MARK: - Naming helpers

    /// Turn a cache folder name (often a bundle id) into something readable.
    private static func friendlyName(_ raw: String) -> String {
        if let known = knownNames[raw] { return known }
        // Bundle-id style "com.acme.Foo" → "Foo".
        if raw.contains("."), let last = raw.split(separator: ".").last {
            return last.prefix(1).uppercased() + last.dropFirst()
        }
        return raw
    }

    private static let knownNames: [String: String] = [
        "Google": "Google Chrome",
        "Chromium": "Chromium",
        "Firefox": "Firefox",
        "BraveSoftware": "Brave",
        "com.operasoftware.Opera": "Opera",
        "com.duckduckgo.macos.browser": "DuckDuckGo",
        "com.apple.Safari": "Safari",
        "JetBrains": "JetBrains IDEs",
        "Adobe": "Adobe",
        "Espressif": "Espressif Tools",
        "arduino": "Arduino",
        "com.spotify.client": "Spotify",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.hnc.Discord": "Discord",
        "typescript": "TypeScript",
        "node-gyp": "node-gyp",
        "composer": "Composer",
        "Movavi": "Movavi",
    ]

    private static func icon(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("google") || n.contains("chrom") || n.contains("firefox")
            || n.contains("opera") || n.contains("brave") || n.contains("safari")
            || n.contains("browser") {
            return "globe"
        }
        if n.contains("discord") || n.contains("slack") || n.contains("telegram") {
            return "message"
        }
        return "shippingbox"
    }
}
