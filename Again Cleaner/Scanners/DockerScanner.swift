//
//  DockerScanner.swift
//  Again Cleaner
//
//  Reports Docker disk usage, correctly separating Build Cache (the usual
//  hidden hog) from images, containers and volumes. Nothing is ever pruned
//  automatically:
//   • Build Cache  → regeneratable, cleaned via `docker builder prune`
//   • Images       → review required, manual
//   • Volumes      → dangerous (may hold databases), manual only
//

import Foundation

struct DockerScanner: CleanupScanner {
    let id = "docker"
    let displayName = "Docker"

    func isAvailable() -> Bool { ProcessRunner.locate("docker") != nil }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        guard let docker = ProcessRunner.locate("docker") else { return [] }

        // Is the engine actually running? `docker info` fails fast if not.
        guard let info = try? await ProcessRunner.run(docker, ["info"], timeout: .seconds(8)),
              info.ok else {
            // Installed but daemon down — surface an informational, non-deletable item.
            return [CleanupCandidate(
                scannerID: "docker:engine",
                name: String(localized: "Docker Engine not running"),
                path: nil, size: 0, risk: .systemProtected,
                explanation: String(localized: "Docker Desktop is installed but the engine is stopped. Start it to analyze build cache, images and volumes."),
                consequence: String(localized: "Launch Docker, then rescan."),
                method: .manualOnly
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
                    path: nil, size: row.reclaimable, risk: .regeneratable,
                    explanation: String(localized: "Cached layers from image builds. Rebuilt automatically on your next `docker build`."),
                    consequence: String(localized: "Removes unused build cache. Containers and volumes are NOT touched."),
                    method: .dockerBuilderPrune
                ))

            case "Local Volumes":
                guard row.reclaimable > 0 else { continue }
                out.append(CleanupCandidate(
                    scannerID: "docker:volumes",
                    name: String(localized: "Docker Volumes (unused)"),
                    path: nil, size: row.reclaimable, risk: .dangerous,
                    explanation: String(localized: "Volumes can hold databases (PostgreSQL, MySQL, Redis…). Never removed automatically."),
                    consequence: String(localized: "Review and remove specific volumes yourself in Docker."),
                    method: .manualOnly
                ))

            case "Images":
                guard row.reclaimable > 0 else { continue }
                out.append(CleanupCandidate(
                    scannerID: "docker:images",
                    name: String(localized: "Docker Images (dangling/unused)"),
                    path: nil, size: row.reclaimable, risk: .reviewRequired,
                    explanation: String(localized: "Unused image layers. Re-pulled or rebuilt when needed."),
                    consequence: String(localized: "Review before pruning — some images may be slow to rebuild."),
                    method: .manualOnly
                ))

            default:
                continue
            }
        }
        return out
    }
}
