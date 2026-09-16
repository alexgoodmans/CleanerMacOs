//
//  AndroidSDKParsing.swift
//  Again Cleaner
//
//  Pure parsers for Android SDK / NDK / AVD / system-image metadata. No
//  filesystem access — scanners feed file contents in.
//

import Foundation

enum AndroidSDKParsing {

    struct SystemImage: Equatable, Sendable {
        let api: String          // "36"
        let flavor: String       // "google_apis" / "google_apis_playstore"
        let abi: String          // "arm64-v8a"
        let relativePath: String // "system-images/android-36/google_apis/arm64-v8a"

        var displayName: String { "API \(api) · \(flavor) · \(abi)" }
    }

    struct AVD: Equatable, Sendable {
        let name: String
        let imageRelativePath: String?
        let abi: String?
        let api: String?
    }

    /// `system-images/android-36/google_apis/arm64-v8a` (with or without trailing slash).
    nonisolated static func parseSystemImagePath(_ relative: String) -> SystemImage? {
        let parts = relative.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        guard parts.count >= 4, parts[0] == "system-images" else { return nil }
        let apiToken = parts[1] // android-36
        let api = apiToken.hasPrefix("android-") ? String(apiToken.dropFirst("android-".count)) : apiToken
        let flavor = parts[2]
        let abi = parts[3]
        let rel = "system-images/android-\(api)/\(flavor)/\(abi)"
        return SystemImage(api: api, flavor: flavor, abi: abi, relativePath: rel)
    }

    /// Parse a `.ini` / `config.ini` blob into a key → value map.
    nonisolated static func ini(_ text: String) -> [String: String] {
        var out: [String: String] = [:]
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            out[key] = value
        }
        return out
    }

    nonisolated static func parseAVD(name: String, configINI: String) -> AVD {
        let map = ini(configINI)
        let image = (map["image.sysdir.1"] ?? map["image.sysdir.2"])?
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parsed = image.flatMap(parseSystemImagePath)
        return AVD(
            name: map["AvdId"] ?? name,
            imageRelativePath: parsed?.relativePath ?? image,
            abi: map["abi.type"] ?? parsed?.abi,
            api: parsed?.api
        )
    }

    /// `sdk.dir=/path` from a Gradle `local.properties` file.
    nonisolated static func sdkDir(fromLocalProperties text: String) -> String? {
        let map = ini(text)
        return map["sdk.dir"] ?? map["ndk.dir"].map { ($0 as NSString).deletingLastPathComponent }
    }

    /// Collect NDK version strings referenced by Gradle / properties text.
    nonisolated static func ndkReferences(in text: String) -> Set<String> {
        var found: Set<String> = []
        let patterns = [
            #"ndkVersion\s*[=\(]?\s*[\"']([^\"']+)[\"']"#,
            #"ndk\.dir\s*=\s*(.+)"#,
            #"ndkPath\s*=\s*[\"']([^\"']+)[\"']"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            for m in matches where m.numberOfRanges >= 2 {
                let raw = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if let version = ndkVersion(fromPathOrValue: raw) {
                    found.insert(version)
                }
            }
        }
        return found
    }

    /// Last path component if it looks like an NDK version (`26.1.10909125`).
    nonisolated static func ndkVersion(fromPathOrValue raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        let last = (trimmed as NSString).lastPathComponent
        // Version folders are dotted numbers, optionally with rc/beta.
        let core = last.split(separator: "-").first.map(String.init) ?? last
        let parts = core.split(separator: ".")
        guard parts.count >= 2, parts.allSatisfy({ Int($0) != nil || $0.allSatisfy(\.isNumber) }) else {
            // Still accept the folder name if it starts with a digit.
            return last.first?.isNumber == true ? last : nil
        }
        return last
    }

    /// True when an installed NDK version is referenced by any project.
    nonisolated static func isReferenced(ndkVersion version: String, references: Set<String>) -> Bool {
        if references.contains(version) { return true }
        // Prefix match: "26.1.10909125" vs "26.1"
        return references.contains { version.hasPrefix($0) || $0.hasPrefix(version) }
    }
}
