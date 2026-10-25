//
//  ContainerScanner.swift
//  Again Cleaner
//
//  Large application containers and Application Support folders. Only the
//  Caches/Logs/tmp inside a container are offered — never the container itself
//  (macOS protects it, and it links back into ~/Library/Keychains).
//

import Foundation

nonisolated struct ContainerScanner: CleanupScanner {
    let id = "containers"
    let displayName = "Application Data"

    private static let minSize: Int64 = 500_000_000

    var ownedPrefixes: [URL] {
        [
            DirListing.home.appendingPathComponent("Library/Containers"),
            DirListing.home.appendingPathComponent("Library/Group Containers"),
        ]
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        out += await scanTree(
            DirListing.home.appendingPathComponent("Library/Containers"),
            kind: "container", ctx: ctx
        )
        out += await scanTree(
            DirListing.home.appendingPathComponent("Library/Group Containers"),
            kind: "group-container", ctx: ctx
        )
        out += await scanAppSupport(ctx)
        return out
    }

    private func scanTree(_ root: URL, kind: String, ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for child in DirListing.children(of: root, dirsOnly: true) {
            if ctx.isCancelled() { break }
            // macOS's own containers (Mail, Safari, Messages…) are never offered;
            // PathGuard refuses them anyway.
            let name = child.lastPathComponent
            if name.hasPrefix("com.apple.") || name.hasPrefix("group.com.apple.")
                || name.contains(".com.apple.") { continue }
            guard let size = await ctx.measured(child), size >= Self.minSize else { continue }
            let children = DirListing.children(of: child, skipHidden: false)
            let names = children.map(\.lastPathComponent)
            if AIModelDetection.isModelDirectory(name: child.lastPathComponent, childNames: names)
                || children.contains(where: { AIModelDetection.isModelFile($0) }) {
                continue // AIModelScanner owns these
            }
            let cacheHits = children.filter {
                ["Caches", "Cache", "Logs", "tmp", "Temp"].contains($0.lastPathComponent)
            }
            for cache in cacheHits {
                if let c = await ctx.candidate(
                    scannerID: "container:\(kind):cache:\(child.lastPathComponent)",
                    name: "\(child.lastPathComponent) · \(cache.lastPathComponent)",
                    url: cache,
                    risk: .usuallySafe,
                    explanation: String(localized: "Cache or logs inside the \(child.lastPathComponent) app container. The rest of the container is application data, not junk."),
                    consequence: String(localized: "Cleared. The app recreates caches."),
                    category: .applicationData, developer: child.lastPathComponent
                ) { out.append(c) }
            }
        }
        return out
    }

    private func scanAppSupport(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let root = DirListing.home.appendingPathComponent("Library/Application Support")
        var out: [CleanupCandidate] = []
        let skip: Set<String> = ["Cursor", "Code", "Steam", "Caches", "Google", "AddressBook"]
        for child in DirListing.children(of: root, dirsOnly: true) {
            if ctx.isCancelled() { break }
            if skip.contains(child.lastPathComponent) { continue }
            guard let size = await ctx.measured(child), size >= Self.minSize else { continue }
            if AIModelDetection.isModelDirectory(
                name: child.lastPathComponent,
                childNames: DirListing.children(of: child).map(\.lastPathComponent)
            ) { continue }
            out.append(CleanupCandidate(
                scannerID: "appsupport:\(child.lastPathComponent)",
                name: child.lastPathComponent,
                path: child,
                size: size,
                risk: .reviewRequired,
                category: .applicationData,
                developer: child.lastPathComponent,
                confidence: .medium,
                isRegenerable: false,
                explanation: String(localized: "Large Application Support folder. A multi-gigabyte support directory is not equivalent to a cache — it may hold licenses, databases or user documents."),
                consequence: String(localized: "Review the contents. Removing this can reset or break the application."),
                lastModified: DirListing.modified(child),
                method: .filesystem
            ))
        }
        return out
    }
}
