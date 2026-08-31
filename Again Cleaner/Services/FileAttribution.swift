//
//  FileAttribution.swift
//  Again Cleaner
//
//  Best-effort guess of which app/project a large file belongs to, from its
//  path alone (no filesystem access, so it's pure and testable). Returns nil
//  when nothing confident can be said.
//

import Foundation

enum FileAttribution {

    nonisolated static func owner(for url: URL) -> String? {
        let comps = url.pathComponents
        let lower = comps.map { $0.lowercased() }

        // VM disk images belong to a virtualizer.
        if FileKind.of(url) == .vm { return String(localized: "Virtual Machine") }

        if lower.contains("coresimulator") { return String(localized: "iOS Simulator") }

        if lower.contains("developer"), lower.contains("xcode") {
            if let i = comps.firstIndex(of: "DerivedData"), i + 1 < comps.count {
                return project(fromDerivedData: comps[i + 1])
            }
            return "Xcode"
        }

        if lower.contains("docker") || lower.contains(".docker") { return "Docker" }

        // A file inside …/node_modules/… belongs to the project above it.
        if let i = comps.firstIndex(of: "node_modules"), i > 0 { return comps[i - 1] }

        // App sandbox container → the bundle id.
        if let i = comps.firstIndex(of: "Containers"), i + 1 < comps.count,
           comps[i + 1].contains(".") { return comps[i + 1] }

        if lower.contains(".gradle") { return "Gradle" }
        if lower.contains(".cargo") || comps.contains("target") && lower.contains("cargo") { return "Rust (Cargo)" }

        return nil
    }

    /// "MyApp-abcdef123" → "MyApp" (DerivedData appends a build hash).
    nonisolated static func project(fromDerivedData folder: String) -> String {
        if let dash = folder.lastIndex(of: "-") {
            return String(folder[folder.startIndex..<dash])
        }
        return folder
    }
}
