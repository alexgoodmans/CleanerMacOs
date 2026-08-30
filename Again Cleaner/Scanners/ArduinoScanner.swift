//
//  ArduinoScanner.swift
//  Again Cleaner
//
//  Large ≠ junk. Arduino/embedded SDKs are big but usually all in use. This
//  scanner reads packages/<vendor>/hardware/<platform>/<version> and only
//  flags OLD core versions when more than one exists — the newest core and ALL
//  compiler/tool chains stay System Protected (they may be used by the current
//  core).
//

import Foundation

nonisolated struct ArduinoScanner: CleanupScanner {
    let id = "arduino"
    let displayName = "Arduino / Embedded SDK"

    private nonisolated static func packagesRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Arduino15/packages")
    }

    nonisolated var ownedPrefixes: [URL] {
        // Only own hardware cores; tools/cache are handled elsewhere or protected.
        [] // handled by explicit per-item paths; no coarse catalog overlap here
    }

    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: Self.packagesRoot().path)
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let fm = FileManager.default
        let root = Self.packagesRoot()
        var out: [CleanupCandidate] = []

        let vendors = (try? fm.contentsOfDirectory(at: root,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []

        for vendor in vendors {
            if ctx.isCancelled() { break }

            // --- hardware cores: flag old versions ---
            let hardware = vendor.appendingPathComponent("hardware")
            let platforms = (try? fm.contentsOfDirectory(at: hardware,
                includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []

            for platform in platforms {
                if ctx.isCancelled() { break }
                let versionDirs = (try? fm.contentsOfDirectory(at: platform,
                    includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
                let versions = versionDirs.map(\.lastPathComponent)
                let old = VersionOrdering.olderThanNewest(versions)

                for vdir in versionDirs {
                    if ctx.isCancelled() { break }
                    let size = await ctx.usage.size(of: vdir, isCancelled: ctx.isCancelled)
                    guard size > 0 else { continue }
                    let isOld = old.contains(vdir.lastPathComponent)
                    let label = "\(vendor.lastPathComponent) \(platform.lastPathComponent) \(vdir.lastPathComponent)"

                    out.append(CleanupCandidate(
                        scannerID: "arduino:core:\(label)",
                        name: label,
                        path: vdir, size: size,
                        risk: isOld ? .reviewRequired : .systemProtected,
                        explanation: isOld
                            ? String(localized: "Old SDK core version — a newer one is installed.")
                            : String(localized: "Current SDK core version — in use by your boards."),
                        consequence: isOld
                            ? String(localized: "Review: keep if any project still targets this version.")
                            : String(localized: "Protected — removing would break builds for this board."),
                        method: .filesystem
                    ))
                }
            }

            // --- tools/toolchains: shown, never offered for deletion ---
            let tools = vendor.appendingPathComponent("tools")
            if fm.fileExists(atPath: tools.path) {
                let size = await ctx.usage.size(of: tools, isCancelled: ctx.isCancelled)
                if size > 0 {
                    out.append(CleanupCandidate(
                        scannerID: "arduino:tools:\(vendor.lastPathComponent)",
                        name: "\(vendor.lastPathComponent) toolchains",
                        path: tools, size: size, risk: .systemProtected,
                        explanation: String(localized: "Compilers, gdb, OpenOCD and libraries used by the installed cores."),
                        consequence: String(localized: "Protected — the current core may depend on these."),
                        method: .manualOnly
                    ))
                }
            }
        }
        return out
    }
}
