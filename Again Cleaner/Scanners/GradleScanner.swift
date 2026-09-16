//
//  GradleScanner.swift
//  Again Cleaner
//
//  Breaks ~/.gradle into caches / tmp / wrapper / JDKs / daemon instead of
//  treating the whole tree as junk.
//

import Foundation

nonisolated struct GradleScanner: CleanupScanner {
    let id = "gradle"
    let displayName = "Gradle"

    private static func root() -> URL {
        DirListing.home.appendingPathComponent(".gradle")
    }

    var ownedPrefixes: [URL] { [Self.root()] }

    func isAvailable() -> Bool { DirListing.exists(Self.root()) }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let root = Self.root()
        var out: [CleanupCandidate] = []

        struct Bucket {
            let rel: String
            let name: String
            let risk: CleanupRisk
            let why: String
            let consequence: String
        }
        let buckets: [Bucket] = [
            .init(rel: "caches", name: String(localized: "Gradle caches"),
                  risk: .usuallySafe,
                  why: String(localized: "Gradle stores downloaded dependencies and compiled metadata here. They can be downloaded or generated again. This is not the entire ~/.gradle directory."),
                  consequence: String(localized: "The next Gradle build re-downloads missing artifacts.")),
            .init(rel: ".tmp", name: String(localized: "Gradle temp"),
                  risk: .safe,
                  why: String(localized: "Temporary Gradle files."),
                  consequence: String(localized: "Removed. Gradle recreates temp files.")),
            .init(rel: "daemon", name: String(localized: "Gradle daemon data"),
                  risk: .usuallySafe,
                  why: String(localized: "Logs and pid files for the Gradle daemon."),
                  consequence: String(localized: "The daemon restarts on the next build.")),
            .init(rel: "native", name: String(localized: "Gradle native cache"),
                  risk: .usuallySafe,
                  why: String(localized: "Extracted native Gradle workers. Regenerated on demand."),
                  consequence: String(localized: "Re-extracted on the next Gradle run.")),
            .init(rel: "wrapper/dists", name: String(localized: "Gradle wrapper distributions"),
                  risk: .reviewRequired,
                  why: String(localized: "Downloaded Gradle wrapper distributions. Removing them forces every project to re-download its Gradle version — not the same as clearing caches."),
                  consequence: String(localized: "The next `./gradlew` re-downloads the distribution.")),
            .init(rel: "jdks", name: String(localized: "Gradle-downloaded JDKs"),
                  risk: .reviewRequired,
                  why: String(localized: "JDKs Gradle downloaded for toolchains. Removing them does not uninstall a system JDK, but the next build will re-download these versions."),
                  consequence: String(localized: "Gradle re-downloads toolchain JDKs when a project needs them.")),
        ]

        for b in buckets {
            if ctx.isCancelled() { break }
            if let c = await ctx.candidate(
                scannerID: "gradle:\(b.rel)",
                name: b.name,
                url: root.appendingPathComponent(b.rel),
                risk: b.risk,
                explanation: b.why,
                consequence: b.consequence,
                category: .gradle,
                developer: "Gradle"
            ) { out.append(c) }
        }
        return out
    }
}
