//
//  AndroidScanner.swift
//  Again Cleaner
//
//  Android SDK, NDK versions, emulator system images and AVDs. SDK path is
//  discovered (env, Studio defaults, local.properties) — never hardcoded to
//  a username. Referenced NDK / images are not ordinary junk.
//

import Foundation

nonisolated struct AndroidScanner: CleanupScanner {
    let id = "android"
    let displayName = "Android"

    var ownedPrefixes: [URL] {
        var urls = [
            DirListing.home.appendingPathComponent(".android"),
            DirListing.home.appendingPathComponent("Library/Android"),
        ]
        urls.append(contentsOf: Self.sdkRoots())
        return urls
    }

    func isAvailable() -> Bool {
        !Self.sdkRoots().isEmpty
            || DirListing.exists(DirListing.home.appendingPathComponent(".android"))
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        let sdkRoots = Self.sdkRoots()
        let references = Self.collectNdkReferences(isCancelled: ctx.isCancelled)

        if let c = await ctx.candidate(
            scannerID: "android:cache",
            name: String(localized: "Android tools cache"),
            url: DirListing.home.appendingPathComponent(".android/cache"),
            risk: .usuallySafe,
            explanation: String(localized: "Android SDK Manager download cache. Re-downloaded as needed."),
            consequence: String(localized: "The next SDK Manager operation re-fetches packages."),
            category: .android, developer: "Android SDK"
        ) { out.append(c) }

        for sdk in sdkRoots {
            if ctx.isCancelled() { break }
            out += await scanNDK(sdk: sdk, references: references, ctx: ctx)
            out += await scanSystemImages(sdk: sdk, ctx: ctx)
            for rel in ["build-tools", "platforms", "cmake", "platform-tools", "emulator"] {
                if ctx.isCancelled() { break }
                let url = sdk.appendingPathComponent(rel)
                if let c = await ctx.candidate(
                    scannerID: "android:sdk:\(rel)",
                    name: "Android SDK · \(rel)",
                    url: url,
                    risk: .neverDeleteAutomatically,
                    explanation: String(localized: "Installed Android SDK component (\(rel)). This is a toolchain, not cache. Removing it breaks builds until you reinstall it."),
                    consequence: String(localized: "SDK Manager can reinstall this component. Not deleted automatically."),
                    category: .android, developer: "Android SDK",
                    method: .manualOnly
                ) { out.append(c) }
            }
        }

        out += await scanAVDs(ctx: ctx)
        return out
    }

    // MARK: - SDK location

    nonisolated static func sdkRoots() -> [URL] {
        var seen: Set<String> = []
        var out: [URL] = []
        func add(_ path: String) {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let key = PathGuard.canonicalPath(url)
            guard DirListing.exists(url), !seen.contains(key) else { return }
            seen.insert(key)
            out.append(url)
        }
        let env = ProcessInfo.processInfo.environment
        if let p = env["ANDROID_SDK_ROOT"], !p.isEmpty { add(p) }
        if let p = env["ANDROID_HOME"], !p.isEmpty { add(p) }
        add(DirListing.home.appendingPathComponent("Library/Android/sdk").path)
        add(DirListing.home.appendingPathComponent("Android/Sdk").path)
        for extra in discoverLocalPropertiesSDK() { add(extra) }
        return out
    }

    /// Shallow walk of likely project folders looking for `sdk.dir=`.
    nonisolated static func discoverLocalPropertiesSDK() -> [String] {
        var found: [String] = []
        let roots = CleanupCatalog.artifactRoots
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }
            var depthGuard = 0
            for case let url as URL in enumerator {
                depthGuard += 1
                if depthGuard > 8_000 { break }
                if url.pathComponents.count - root.pathComponents.count > 6 {
                    enumerator.skipDescendants(); continue
                }
                if url.lastPathComponent == "node_modules" || url.lastPathComponent == ".git" {
                    enumerator.skipDescendants(); continue
                }
                guard url.lastPathComponent == "local.properties" else { continue }
                if let text = try? String(contentsOf: url, encoding: .utf8),
                   let dir = AndroidSDKParsing.sdkDir(fromLocalProperties: text) {
                    found.append(dir)
                }
            }
        }
        return found
    }

    nonisolated static func collectNdkReferences(isCancelled: () -> Bool) -> Set<String> {
        var refs: Set<String> = []
        for root in CleanupCatalog.artifactRoots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }
            var n = 0
            for case let url as URL in enumerator {
                if isCancelled() { return refs }
                n += 1
                if n > 12_000 { break }
                let name = url.lastPathComponent
                if name == "node_modules" || name == ".git" || name == "build" {
                    enumerator.skipDescendants(); continue
                }
                guard ["local.properties", "build.gradle", "build.gradle.kts",
                       "gradle.properties"].contains(name) else { continue }
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    refs.formUnion(AndroidSDKParsing.ndkReferences(in: text))
                }
            }
        }
        return refs
    }

    // MARK: - NDK

    private func scanNDK(sdk: URL, references: Set<String>, ctx: ScanContext) async -> [CleanupCandidate] {
        let ndkRoot = sdk.appendingPathComponent("ndk")
        let versions = DirListing.children(of: ndkRoot, dirsOnly: true)
        let onlyOne = versions.count == 1
        var out: [CleanupCandidate] = []
        for dir in versions {
            if ctx.isCancelled() { break }
            let version = dir.lastPathComponent
            let referenced = AndroidSDKParsing.isReferenced(ndkVersion: version, references: references)
            let keep = onlyOne || referenced
            let risk: CleanupRisk = keep ? .neverDeleteAutomatically : .reviewRequired
            if let c = await ctx.candidate(
                scannerID: "android:ndk:\(version)",
                name: "Android NDK \(version)",
                url: dir,
                risk: risk,
                explanation: keep
                    ? (onlyOne
                       ? String(localized: "This is the only installed Android NDK. It is a native toolchain, not cache.")
                       : String(localized: "This NDK version is referenced by a discovered project (ndkVersion / ndk.dir / ndkPath)."))
                    : String(localized: "This is an installed Android native toolchain. No currently discovered project references this version. Android Studio can reinstall it."),
                consequence: keep
                    ? String(localized: "Protected — removing it would break native builds.")
                    : String(localized: "Review before removing. SDK Manager can reinstall this NDK."),
                category: .android, subcategory: version, developer: "Android NDK",
                method: keep ? .manualOnly : .filesystem
            ) { out.append(c) }
        }
        return out
    }

    // MARK: - System images + AVDs

    private func scanSystemImages(sdk: URL, ctx: ScanContext) async -> [CleanupCandidate] {
        let root = sdk.appendingPathComponent("system-images")
        let referenced = Self.referencedImagePaths()
        var out: [CleanupCandidate] = []
        for apiDir in DirListing.children(of: root, dirsOnly: true) {
            for flavor in DirListing.children(of: apiDir, dirsOnly: true) {
                for abi in DirListing.children(of: flavor, dirsOnly: true) {
                    if ctx.isCancelled() { return out }
                    let rel = "system-images/\(apiDir.lastPathComponent)/\(flavor.lastPathComponent)/\(abi.lastPathComponent)"
                    let parsed = AndroidSDKParsing.parseSystemImagePath(rel)
                    let used = referenced.contains { ref in
                        let r = ref.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        return r.hasSuffix(rel) || rel.hasSuffix(r) || r.contains(rel) || abi.path.contains(r)
                    }
                    let risk: CleanupRisk = used ? .neverDeleteAutomatically : .reviewRequired
                    if let c = await ctx.candidate(
                        scannerID: "android:image:\(rel)",
                        name: parsed?.displayName ?? rel,
                        url: abi,
                        risk: risk,
                        explanation: used
                            ? String(localized: "Android emulator system image in use by an AVD. API \(parsed?.api ?? "?"), \(parsed?.flavor ?? flavor.lastPathComponent), \(parsed?.abi ?? abi.lastPathComponent).")
                            : String(localized: "Android emulator system image not referenced by any AVD. API \(parsed?.api ?? "?"), \(parsed?.flavor ?? flavor.lastPathComponent), \(parsed?.abi ?? abi.lastPathComponent). SDK Manager can reinstall it."),
                        consequence: used
                            ? String(localized: "Protected — an emulator needs this image.")
                            : String(localized: "Removing it frees space. Recreate via SDK Manager if you need this emulator image later."),
                        category: .android, developer: "Android Emulator",
                        method: used ? .manualOnly : .filesystem
                    ) { out.append(c) }
                }
            }
        }
        return out
    }

    private func scanAVDs(ctx: ScanContext) async -> [CleanupCandidate] {
        let avdRoot = DirListing.home.appendingPathComponent(".android/avd")
        var out: [CleanupCandidate] = []
        for dir in DirListing.children(of: avdRoot, dirsOnly: true) where dir.pathExtension == "avd" {
            if ctx.isCancelled() { break }
            let config = dir.appendingPathComponent("config.ini")
            let text = (try? String(contentsOf: config, encoding: .utf8)) ?? ""
            let parsed = AndroidSDKParsing.parseAVD(name: dir.deletingPathExtension().lastPathComponent, configINI: text)
            let modified = DirListing.modified(dir)
            if let c = await ctx.candidate(
                scannerID: "android:avd:\(parsed.name)",
                name: "AVD · \(parsed.name)",
                url: dir,
                risk: .reviewRequired,
                explanation: String(localized: "This is a complete Android virtual device including its internal user data. Android \(parsed.api ?? "?"), \(parsed.abi ?? "?"). Image: \(parsed.imageRelativePath ?? "unknown"). Last modified: \(DirListing.shortDate(modified)). Removing it deletes that virtual phone."),
                consequence: String(localized: "The emulator and all apps/data inside it are gone. You would recreate it from scratch."),
                category: .android, subcategory: parsed.imageRelativePath, developer: "Android Emulator"
            ) { out.append(c) }
        }
        return out
    }

    nonisolated static func referencedImagePaths() -> [String] {
        let avdRoot = DirListing.home.appendingPathComponent(".android/avd")
        var out: [String] = []
        let items = (try? FileManager.default.contentsOfDirectory(
            at: avdRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        for url in items {
            let config: URL
            if url.pathExtension == "avd" {
                config = url.appendingPathComponent("config.ini")
            } else if url.pathExtension == "ini" {
                config = url
            } else { continue }
            guard let text = try? String(contentsOf: config, encoding: .utf8) else { continue }
            let map = AndroidSDKParsing.ini(text)
            if let image = map["image.sysdir.1"] { out.append(image) }
            if let path = map["path"] { out.append(path) }
        }
        return out
    }
}
