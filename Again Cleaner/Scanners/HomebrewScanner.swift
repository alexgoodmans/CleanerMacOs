//
//  HomebrewScanner.swift
//  Again Cleaner
//
//  Reports how much `brew cleanup` would free, using Homebrew's own dry run so
//  the number is authoritative. Cleanup runs the real `brew cleanup` — never a
//  hand-rolled `rm` of the Cellar.
//

import Foundation

nonisolated struct HomebrewScanner: CleanupScanner {
    let id = "homebrew"
    let displayName = "Homebrew"

    func isAvailable() -> Bool { ProcessRunner.locate("brew") != nil }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        guard let brew = ProcessRunner.locate("brew") else { return [] }
        guard let dry = try? await ProcessRunner.run(brew, ["cleanup", "--dry-run"], timeout: .seconds(30)),
              dry.ok else { return [] }

        let freeable = Self.parseFreeable(dry.stdout)
        guard freeable > 0 else { return [] }

        return [CleanupCandidate(
            scannerID: "homebrew:cleanup",
            name: String(localized: "Homebrew Cleanup"),
            path: nil, size: freeable, risk: .usuallySafe,
            explanation: String(localized: "Old formula versions and cached downloads Homebrew no longer needs."),
            consequence: String(localized: "Runs `brew cleanup`. Installed packages keep working."),
            method: .homebrewCleanup
        )]
    }

    /// Extract bytes from Homebrew's "would free approximately X" line.
    nonisolated static func parseFreeable(_ output: String) -> Int64 {
        for line in output.split(separator: "\n") {
            let text = line.lowercased()
            guard text.contains("would free approximately") else { continue }
            // …approximately 2.5GB of disk space.
            if let range = text.range(of: "approximately ") {
                let after = text[range.upperBound...]
                let token = after.split(whereSeparator: { $0 == " " }).first.map(String.init) ?? ""
                return DockerParsing.bytes(from: token.uppercased())
            }
        }
        return 0
    }
}
