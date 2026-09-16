//
//  DockerScanner.swift
//  Again Cleaner
//
//  Reports Docker disk usage via `docker system df` (authoritative).
//  Build cache is usuallySafe; images are reviewRequired; volumes are
//  reviewRequired and never treated as cache (they may hold databases).
//

import Foundation

nonisolated struct DockerScanner: CleanupScanner {
    let id = "docker"
    let displayName = "Docker"

    func isAvailable() -> Bool { ProcessRunner.locate("docker") != nil }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        guard let docker = ProcessRunner.locate("docker") else { return [] }

        guard let info = try? await ProcessRunner.run(docker, ["info"], timeout: .seconds(8)),
              info.ok else {
            return [CleanupCandidate(
                scannerID: "docker:engine",
                name: String(localized: "Docker Engine not running"),
                path: nil, size: 0, risk: .neverDeleteAutomatically,
                category: .docker, confidence: .high,
                explanation: String(localized: "Docker Desktop is installed but the engine is stopped. Start it to analyze build cache, images and volumes."),
                consequence: String(localized: "Launch Docker, then rescan."),
                method: .manualOnly,
                accessState: .inaccessible
            )]
        }

        guard let df = try? await ProcessRunner.run(docker, ["system", "df"], timeout: .seconds(15)),
              df.ok else { return [] }

        var out: [CleanupCandidate] = []
        for row in DockerParsing.parseSystemDF(df.stdout) {
            switch row.type {
            case "Build Cache":
                guard row.reclaimable > 0 else { continue }
                out.append(CleanupCandidate(
                    scannerID: "docker:build-cache",
                    name: String(localized: "Docker Build Cache"),
                    path: nil, size: row.size,
                    reclaimableBytes: row.reclaimable,
                    risk: .usuallySafe,
                    category: .docker, developer: "Docker",
                    explanation: String(localized: "Cached layers from image builds. Allocated \(DirListing.bytes(row.size)); Docker reports \(DirListing.bytes(row.reclaimable)) reclaimable. Rebuilt on the next `docker build`."),
                    consequence: String(localized: "Removes unused build cache. Containers and volumes are NOT touched."),
                    method: .dockerBuilderPrune
                ))

            case "Local Volumes":
                guard row.size > 0 else { continue }
                out.append(CleanupCandidate(
                    scannerID: "docker:volumes",
                    name: String(localized: "Docker Volumes"),
                    path: nil, size: row.size,
                    reclaimableBytes: row.reclaimable,
                    risk: .reviewRequired,
                    category: .docker, developer: "Docker",
                    confidence: .high,
                    isRegenerable: false,
                    explanation: String(localized: "Docker volumes can hold databases (PostgreSQL, MySQL, Redis) or persistent app data. Allocated \(DirListing.bytes(row.size)); unused according to Docker: \(DirListing.bytes(row.reclaimable)). Unused volumes are NOT automatically safe."),
                    consequence: String(localized: "Review each volume. Again Cleaner will not prune volumes automatically."),
                    method: .manualOnly
                ))

            case "Images":
                guard row.reclaimable > 0 else { continue }
                out.append(CleanupCandidate(
                    scannerID: "docker:images",
                    name: String(localized: "Docker Images (dangling/unused)"),
                    path: nil, size: row.size,
                    reclaimableBytes: row.reclaimable,
                    risk: .reviewRequired,
                    category: .docker, developer: "Docker",
                    explanation: String(localized: "Image layers. Allocated \(DirListing.bytes(row.size)); Docker reports \(DirListing.bytes(row.reclaimable)) reclaimable. Re-pulled or rebuilt when needed."),
                    consequence: String(localized: "Runs `docker image prune` for dangling images only. Named images you still use are kept."),
                    method: .dockerImagePrune
                ))

            default:
                continue
            }
        }
        return out
    }
}
