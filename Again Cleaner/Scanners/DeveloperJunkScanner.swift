//
//  DeveloperJunkScanner.swift
//  Again Cleaner
//
//  Finds regenerable build artifacts under project roots anywhere in the
//  home folder (not only ~/Projects). Ambiguous names like `build` only match
//  when a nearby marker proves the parent is a real project.
//

import Foundation

nonisolated struct DeveloperJunkScanner: CleanupScanner {
    let id = "devjunk"
    let displayName = "Developer Junk"

    private static let names: Set<String> = [
        "node_modules", "target", "build", "dist", "out", "vendor",
        "__pycache__", ".venv", "venv", ".tox", ".pytest_cache",
        ".mypy_cache", ".ruff_cache",
        ".next", ".nuxt", ".turbo", ".parcel-cache", ".angular",
        "_build", ".dart_tool", ".build", "Pods", "DerivedData",
        "bin", "obj", "cmake-build-*", ".cxx", ".gradle",
    ]

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        for root in CleanupCatalog.artifactRoots {
            if ctx.isCancelled() { break }
            let matches = FileSystemEngine.artifactDirectories(named: Self.names, under: root)
            for url in matches {
                if ctx.isCancelled() { break }
                let name = url.lastPathComponent
                let project = url.deletingLastPathComponent().lastPathComponent
                let info = ProjectRootDetector.explanation(forArtifact: name.hasPrefix("cmake-build-") ? "build" : name)
                if let c = await ctx.candidate(
                    scannerID: "devjunk:\(url.path)",
                    name: "\(project) · \(info.type)",
                    url: url,
                    risk: .usuallySafe,
                    explanation: String(localized: "\(info.why) Project: \(project)."),
                    consequence: info.recovery,
                    category: .developerJunk,
                    subcategory: info.type,
                    developer: project
                ) { out.append(c) }
            }
        }
        return out
    }
}
