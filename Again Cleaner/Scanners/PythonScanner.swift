//
//  PythonScanner.swift
//  Again Cleaner
//
//  Enumerates Python.framework versions and user-managed interpreters.
//  Never deletes an interpreter automatically.
//

import Foundation

nonisolated struct PythonScanner: CleanupScanner {
    let id = "python"
    let displayName = "Python"

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        var out: [CleanupCandidate] = []
        let current = ProcessRunner.locate("python3")

        let framework = URL(fileURLWithPath: "/Library/Frameworks/Python.framework/Versions")
        let versions = DirListing.children(of: framework, dirsOnly: true)
        for dir in versions {
            if ctx.isCancelled() { break }
            let exe = dir.appendingPathComponent("bin/python3")
            let referenced = current.map { PathGuard.canonicalPath(URL(fileURLWithPath: $0)) }
                .map { $0.hasPrefix(PathGuard.canonicalPath(dir)) } ?? false
            if let c = await ctx.candidate(
                scannerID: "python:framework:\(dir.lastPathComponent)",
                name: "Python \(dir.lastPathComponent)",
                url: dir,
                risk: .reviewRequired,
                explanation: String(localized: "Python.framework version \(dir.lastPathComponent). Executable: \(exe.path). \(referenced ? "This appears to be the current interpreter." : "This may be an older interpreter.") Python installations are not junk."),
                consequence: String(localized: "Removing an interpreter breaks scripts and venvs that point at it. Again Cleaner will not delete this automatically."),
                category: .python, subcategory: dir.lastPathComponent, developer: "Python",
                method: .manualOnly
            ) {
                // Framework lives under /Library which PathGuard blocks — force manual.
                out.append(CleanupCandidate(
                    scannerID: c.scannerID, name: c.name, path: c.path, size: c.size,
                    risk: .reviewRequired, category: .python,
                    subcategory: dir.lastPathComponent, developer: "Python",
                    explanation: c.explanation, consequence: c.consequence,
                    lastModified: c.lastModified, method: .manualOnly
                ))
            }
        }

        let pyenv = DirListing.home.appendingPathComponent(".pyenv/versions")
        for dir in DirListing.children(of: pyenv, dirsOnly: true) {
            if ctx.isCancelled() { break }
            if let c = await ctx.candidate(
                scannerID: "python:pyenv:\(dir.lastPathComponent)",
                name: "pyenv \(dir.lastPathComponent)",
                url: dir,
                risk: .reviewRequired,
                explanation: String(localized: "User-managed pyenv interpreter \(dir.lastPathComponent). Virtualenvs that pin this version will break if it is removed."),
                consequence: String(localized: "Reinstall with pyenv if you still need this version."),
                category: .python, developer: "pyenv"
            ) { out.append(c) }
        }
        return out
    }
}
