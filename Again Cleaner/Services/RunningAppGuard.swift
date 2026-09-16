//
//  RunningAppGuard.swift
//  Again Cleaner
//
//  Detects whether an app whose data we're about to clean is currently running.
//  Cleaning a live app's caches/storage can corrupt its state, so the UI warns
//  and offers "Quit & Clean" before touching those items.
//

import Foundation
import AppKit

@MainActor
enum RunningAppGuard {

    /// App display names (as shown by macOS) that a candidate belongs to.
    /// Matched against the candidate's scanner id and path.
    private static func appName(for c: CleanupCandidate) -> String? {
        let id = c.scannerID.lowercased()
        let path = (c.path?.path ?? "").lowercased()
        func has(_ s: String) -> Bool { id.contains(s) || path.contains(s) }

        if has("cursor")                                   { return "Cursor" }
        if has("google/chrome") || has("chrome")           { return "Google Chrome" }
        if has("device-support") || has("developer/xcode") || has("derived") || has("xcode") { return "Xcode" }
        if has("docker")                                    { return "Docker Desktop" }
        if has("/code/") || id.hasPrefix("builtin:vscode") || has("vscode") { return "Code" }
        if has("steam")                                     { return "Steam" }
        if has("android")                                   { return "Android Studio" }
        if has("adobe")                                     { return "Adobe" }
        if has("gradle")                                    { return "Android Studio" }
        if has("arduino")                                   { return "Arduino IDE" }
        return nil
    }

    private static func instances(named name: String) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            ($0.localizedName ?? "").caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// Distinct names of apps that are BOTH referenced by the selection AND
    /// currently running — i.e. the user should quit them first.
    static func blockingApps(for candidates: [CleanupCandidate]) -> [String] {
        let names = Set(candidates.compactMap(appName(for:)))
        return names.filter { !instances(named: $0).isEmpty }.sorted()
    }

    /// Ask the named apps to quit (graceful terminate). Returns immediately;
    /// the caller should wait briefly before re-checking.
    static func quit(_ names: [String]) {
        for name in names {
            for app in instances(named: name) { app.terminate() }
        }
    }
}
