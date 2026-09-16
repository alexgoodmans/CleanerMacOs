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

nonisolated enum CleanupCatalog {

    private static let fm = FileManager.default
    private static let home = FileManager.default.homeDirectoryForCurrentUser

    private static func h(_ path: String) -> URL {
        home.appendingPathComponent(path)
    }

    /// Everything the app knows about, in display order.
    static var all: [JunkCategory] {
        curated + otherAppCaches() + electronAppCaches() + userFolders()
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

            // ── More package/tool caches ───────────────────────────────────
            JunkCategory(
                id: "gomod",
                title: String(localized: "Go Module Cache"),
                subtitle: String(localized: "~/go/pkg/mod — re-downloaded on next build"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h("go/pkg/mod")])
            ),
            JunkCategory(
                id: "nuget",
                title: String(localized: "NuGet Packages"),
                subtitle: String(localized: "~/.nuget/packages — restored by dotnet"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h(".nuget/packages")])
            ),
            JunkCategory(
                id: "conan",
                title: String(localized: "Conan Cache"),
                subtitle: String(localized: "~/.conan2/p — C/C++ package cache"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h(".conan2/p")])
            ),
            JunkCategory(
                id: "bun",
                title: String(localized: "Bun Cache"),
                subtitle: String(localized: "~/.bun/install/cache"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h(".bun/install/cache")])
            ),
            JunkCategory(
                id: "android-cache",
                title: String(localized: "Android Tools Cache"),
                subtitle: String(localized: "~/.android/cache"),
                systemImage: "cube.box",
                safety: .caution,
                rule: .clearContents([h(".android/cache")])
            ),

            // ── Apple system leftovers ─────────────────────────────────────
            JunkCategory(
                id: "ios-backups",
                title: String(localized: "iOS Device Backups"),
                subtitle: String(localized: "Old iPhone/iPad backups — check before deleting!"),
                systemImage: "iphone.and.arrow.forward",
                safety: .risky,
                rule: .clearContents([h("Library/Application Support/MobileSync/Backup")])
            ),
            JunkCategory(
                id: "ios-simulators",
                title: String(localized: "iOS Simulators"),
                subtitle: String(localized: "CoreSimulator devices & caches — recreated by Xcode"),
                systemImage: "ipad.and.iphone",
                safety: .caution,
                rule: .clearContents([
                    h("Library/Developer/CoreSimulator/Devices"),
                    h("Library/Developer/CoreSimulator/Caches"),
                ])
            ),
            JunkCategory(
                id: "xcode-devicelogs",
                title: String(localized: "iOS Device Logs"),
                subtitle: String(localized: "~/Library/Developer/Xcode/iOS Device Logs"),
                systemImage: "doc.text.magnifyingglass",
                safety: .safe,
                rule: .clearContents([h("Library/Developer/Xcode/iOS Device Logs")])
            ),
            JunkCategory(
                id: "mail-downloads",
                title: String(localized: "Mail Downloads"),
                subtitle: String(localized: "Viewed attachments Mail forgets to delete"),
                systemImage: "envelope.open",
                safety: .caution,
                rule: .clearContents([h("Library/Containers/com.apple.mail/Data/Library/Mail Downloads")])
            ),
            JunkCategory(
                id: "saved-state",
                title: String(localized: "Saved Application State"),
                subtitle: String(localized: "Window states — apps just reopen fresh"),
                systemImage: "macwindow",
                safety: .caution,
                rule: .clearContents([h("Library/Saved Application State")])
            ),
            JunkCategory(
                id: "itunes-ipa",
                title: String(localized: "iTunes Mobile Apps"),
                subtitle: String(localized: "Old .ipa files from iTunes syncs"),
                systemImage: "square.and.arrow.down",
                safety: .caution,
                rule: .clearContents([h("Music/iTunes/iTunes Media/Mobile Applications")])
            ),

            // ── App-specific heavy caches ──────────────────────────────────
            JunkCategory(
                id: "adobe-media",
                title: String(localized: "Adobe Media Cache"),
                subtitle: String(localized: "Premiere/After Effects render cache"),
                systemImage: "film",
                safety: .caution,
                rule: .clearContents([h("Library/Application Support/Adobe/Common/Media Cache Files")])
            ),
            JunkCategory(
                id: "dropbox-cache",
                title: String(localized: "Dropbox Cache"),
                subtitle: String(localized: "~/Dropbox/.dropbox.cache"),
                systemImage: "shippingbox",
                safety: .caution,
                rule: .clearContents([h("Dropbox/.dropbox.cache")])
            ),
            JunkCategory(
                id: "steam",
                title: String(localized: "Steam Caches"),
                subtitle: String(localized: "appcache / depotcache / shadercache / logs"),
                systemImage: "gamecontroller",
                safety: .caution,
                rule: .removePaths([
                    h("Library/Application Support/Steam/appcache"),
                    h("Library/Application Support/Steam/depotcache"),
                    h("Library/Application Support/Steam/logs"),
                    h("Library/Application Support/Steam/steamapps/shadercache"),
                    h("Library/Application Support/Steam/steamapps/temp"),
                    h("Library/Application Support/Steam/steamapps/download"),
                ])
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

        ] + projectArtifactCategories()
    }

    // MARK: - Universal build artifacts (whole home, any language)

    /// UserDefaults key with extra user-defined scan roots (absolute paths),
    /// e.g. project folders on external volumes outside the home directory.
    static let customProjectRootsKey = "customProjectRoots"

    /// Roots to scan for build artifacts: the whole home folder (system and
    /// media folders are pruned inside the engine) plus any custom roots that
    /// live outside of it.
    static var artifactRoots: [URL] {
        var roots = [home]
        let custom = UserDefaults.standard.stringArray(forKey: customProjectRootsKey) ?? []
        for path in custom {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue,
                  !url.path.hasPrefix(home.path) else { continue }
            roots.append(url)
        }
        return roots
    }

    private static func projectArtifactCategories() -> [JunkCategory] {
        let roots = artifactRoots
        return [
            JunkCategory(
                id: "node-modules",
                title: "node_modules",
                subtitle: String(localized: "Found anywhere in your home folder — restore with `npm install`"),
                systemImage: "folder.badge.gearshape",
                safety: .risky,
                rule: .scanArtifacts(roots: roots, names: ["node_modules"])
            ),
            JunkCategory(
                id: "build-dirs",
                title: String(localized: "Build artifacts (Rust, Java, Python, PHP…)"),
                subtitle: String(localized: "target / build / dist / vendor / __pycache__ / .venv and more"),
                systemImage: "folder.badge.gearshape",
                safety: .risky,
                rule: .scanArtifacts(roots: roots, names: [
                    "target", "build", "dist", "out", "vendor",
                    "__pycache__", ".venv", "venv", ".tox", ".pytest_cache",
                    ".mypy_cache", ".ruff_cache",
                    ".next", ".nuxt", ".turbo", ".parcel-cache", ".angular",
                    "_build", ".dart_tool", ".build", "Pods", "DerivedData",
                    "bin", "obj", "cmake-build-*", ".cxx", ".gradle",
                ])
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

    // MARK: - Generated: Electron/Chromium app caches in Application Support

    /// Junk subfolders every Electron/Chromium-based app accumulates inside
    /// its ~/Library/Application Support/<App>/ directory. One generated
    /// category per app — Discord, Slack, Obsidian, Postman, browsers… all
    /// covered without a hand-maintained list.
    private static let electronJunkNames = [
        "Cache", "Code Cache", "GPUCache",
        "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache",
        "GrShaderCache", "ShaderCache", "logs",
    ]

    /// Apps whose Application Support caches are already curated above.
    private static let curatedAppSupportNames: Set<String> = ["Cursor", "Code", "Steam"]

    /// A top-level Application Support folder that holds a regenerable, on-demand
    /// ML model (e.g. Xcode's `OptGuideOnDeviceModel`) rather than user data.
    /// Matched by name so future Apple/third-party model folders are caught too.
    private static func isRegenerableModelFolder(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.contains("ondevicemodel")
            || n.hasSuffix("modelcatalog")
            || n == "optguideondevicemodel"
    }

    private static func electronAppCaches() -> [JunkCategory] {
        let appSupport = h("Library/Application Support")
        let apps = (try? fm.contentsOfDirectory(
            at: appSupport,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var categories: [JunkCategory] = apps.compactMap { appDir -> JunkCategory? in
            let isDir = (try? appDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let name = appDir.lastPathComponent
            guard isDir, !curatedAppSupportNames.contains(name) else { return nil }

            // On-device ML models (Xcode's OptGuideOnDeviceModel, and similar):
            // large, versioned, and always re-downloaded on demand. Safe to
            // surface as a whole folder — unlike arbitrary app data.
            if isRegenerableModelFolder(name) {
                return JunkCategory(
                    id: "model:\(name)",
                    title: friendlyName(name),
                    subtitle: String(localized: "On-device model — re-downloaded on demand"),
                    systemImage: "brain",
                    safety: .caution,
                    rule: .clearContents([appDir])
                )
            }

            let junk = electronJunkNames
                .map { appDir.appendingPathComponent($0) }
                .filter { fm.fileExists(atPath: $0.path) }
            guard !junk.isEmpty else { return nil }

            return JunkCategory(
                id: "electron:\(name)",
                title: friendlyName(name),
                subtitle: String(localized: "App caches & logs in Application Support"),
                systemImage: "app.dashed",
                safety: .caution,
                rule: .removePaths(junk)
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        // Google Drive: per-account content_cache lives one level deeper.
        let driveFS = h("Library/Application Support/Google/DriveFS")
        if let accounts = try? fm.contentsOfDirectory(at: driveFS, includingPropertiesForKeys: nil) {
            let caches = accounts
                .map { $0.appendingPathComponent("content_cache") }
                .filter { fm.fileExists(atPath: $0.path) }
            if !caches.isEmpty {
                categories.append(JunkCategory(
                    id: "drivefs-cache",
                    title: String(localized: "Google Drive Cache"),
                    subtitle: String(localized: "Offline file cache — re-synced on demand"),
                    systemImage: "arrow.triangle.2.circlepath.icloud",
                    safety: .caution,
                    rule: .removePaths(caches)
                ))
            }
        }
        return categories
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
            // Review-only: the biggest Application Support folders. These hold
            // real app data (databases, profiles, licenses) — never pre-selected,
            // shown so a 4 GB surprise can't hide. Folders with a dedicated
            // category above are excluded to avoid double-listing.
            JunkCategory(
                id: "appsupport-large",
                title: String(localized: "Large App Data (review)"),
                subtitle: String(localized: "Biggest folders in Application Support — real app data, check before removing"),
                systemImage: "externaldrive.badge.questionmark",
                safety: .risky,
                rule: .largeChildren(
                    dir: h("Library/Application Support"),
                    minSize: 500_000_000,
                    exclude: ["Cursor", "Code", "Steam", "Caches"]
                )
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
        "OptGuideOnDeviceModel": "Xcode Predictive Model",
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
