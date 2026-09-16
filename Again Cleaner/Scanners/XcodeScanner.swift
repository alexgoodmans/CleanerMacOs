//
//  XcodeScanner.swift
//  Again Cleaner
//
//  Splits Xcode storage: DerivedData (safe), Archives (review), Simulators
//  (usually safe), caches. DeviceSupport is owned by DeviceSupportScanner.
//

import Foundation

nonisolated struct XcodeScanner: CleanupScanner {
    let id = "xcode"
    let displayName = "Xcode"

    private static func home() -> URL { DirListing.home }

    var ownedPrefixes: [URL] {
        let h = Self.home()
        return [
            h.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            h.appendingPathComponent("Library/Developer/Xcode/Archives"),
            h.appendingPathComponent("Library/Developer/CoreSimulator"),
            h.appendingPathComponent("Library/Developer/Xcode/iOS Device Logs"),
        ]
    }

    func isAvailable() -> Bool {
        DirListing.exists(Self.home().appendingPathComponent("Library/Developer/Xcode"))
    }

    func scan(_ ctx: ScanContext) async -> [CleanupCandidate] {
        let h = Self.home()
        var out: [CleanupCandidate] = []

        if let c = await ctx.candidate(
            scannerID: "xcode:deriveddata",
            name: String(localized: "Xcode DerivedData"),
            url: h.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            risk: .safe,
            explanation: String(localized: "Build intermediates, indexes and logs. Source code is not stored here. Xcode rebuilds this on the next build."),
            consequence: String(localized: "The next build is slower while Xcode regenerates DerivedData."),
            category: .xcode, developer: "Xcode"
        ) { out.append(c) }

        if let c = await ctx.candidate(
            scannerID: "xcode:archives",
            name: String(localized: "Xcode Archives"),
            url: h.appendingPathComponent("Library/Developer/Xcode/Archives"),
            risk: .reviewRequired,
            explanation: String(localized: "Archived release builds. These may be the only copy of a shipped binary — they are not junk."),
            consequence: String(localized: "You cannot re-submit or symbolicate old releases without these archives."),
            category: .xcode, developer: "Xcode",
            confidence: .high
        ) { out.append(c) }

        if let c = await ctx.candidate(
            scannerID: "xcode:simulators",
            name: String(localized: "iOS Simulator data"),
            url: h.appendingPathComponent("Library/Developer/CoreSimulator/Devices"),
            risk: .usuallySafe,
            explanation: String(localized: "Simulator devices and their internal data. Xcode can recreate simulators; app data inside them is lost."),
            consequence: String(localized: "Simulators are recreated. Installed test apps and simulator user data are gone."),
            category: .xcode, developer: "Xcode"
        ) { out.append(c) }

        if let c = await ctx.candidate(
            scannerID: "xcode:sim-caches",
            name: String(localized: "iOS Simulator caches"),
            url: h.appendingPathComponent("Library/Developer/CoreSimulator/Caches"),
            risk: .usuallySafe,
            explanation: String(localized: "CoreSimulator caches. Regenerated when you next boot a simulator."),
            consequence: String(localized: "Xcode rebuilds simulator caches as needed."),
            category: .xcode, developer: "Xcode"
        ) { out.append(c) }

        if let c = await ctx.candidate(
            scannerID: "xcode:devicelogs",
            name: String(localized: "iOS Device Logs"),
            url: h.appendingPathComponent("Library/Developer/Xcode/iOS Device Logs"),
            risk: .safe,
            explanation: String(localized: "Copied device logs. Diagnostic only."),
            consequence: String(localized: "Removed. New logs appear the next time you capture them."),
            category: .xcode, developer: "Xcode"
        ) { out.append(c) }

        return out
    }
}
