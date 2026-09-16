//
//  ScanCategory.swift
//  Again Cleaner
//
//  Logical grouping for Smart Scan. Risk (how safe) and category (what kind
//  of thing) are independent: a Gradle cache is "usually safe" AND "Gradle".
//

import Foundation

/// Confidence that the classification (risk, regenerable, owner) is correct.
nonisolated enum ScanConfidence: Int, Codable, Sendable, CaseIterable {
    case high
    case medium
    case low
    case unknown

    var label: String {
        switch self {
        case .high:    return String(localized: "High confidence")
        case .medium:  return String(localized: "Medium confidence")
        case .low:     return String(localized: "Low confidence")
        case .unknown: return String(localized: "Unverified")
        }
    }
}

/// Outcome of measuring a path. Inaccessible folders are never reported as
/// empty (size 0) — they carry this state instead.
nonisolated enum ScanAccessState: String, Codable, Sendable {
    case scanned
    case inaccessible
    case permissionRequired
    case failed
    case cancelled
}

/// UI / grouping category. Inferred from scanner IDs when a scanner does not
/// set one explicitly.
nonisolated enum ScanCategory: String, CaseIterable, Sendable, Identifiable {
    case safeCleanup
    case appCaches
    case logs
    case developerJunk
    case xcode
    case android
    case gradle
    case arduino
    case cursorIDE
    case docker
    case largeDownloads
    case largeFiles
    case localAIModels
    case applicationData
    case systemStorage
    case trash
    case leftover
    case applications
    case snapshots
    case browsers
    case python
    case reviewRequired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safeCleanup:     return String(localized: "Safe Cleanup")
        case .appCaches:       return String(localized: "App Caches")
        case .logs:            return String(localized: "Logs")
        case .developerJunk:   return String(localized: "Developer Junk")
        case .xcode:           return String(localized: "Xcode")
        case .android:         return String(localized: "Android")
        case .gradle:          return String(localized: "Gradle")
        case .arduino:         return String(localized: "Arduino")
        case .cursorIDE:       return String(localized: "Cursor / IDE")
        case .docker:          return String(localized: "Docker")
        case .largeDownloads:  return String(localized: "Large Downloads")
        case .largeFiles:      return String(localized: "Large Files")
        case .localAIModels:   return String(localized: "Local AI Models")
        case .applicationData: return String(localized: "Application Data")
        case .systemStorage:   return String(localized: "System Storage")
        case .trash:           return String(localized: "Trash")
        case .leftover:        return String(localized: "Leftover App Data")
        case .applications:    return String(localized: "Installed Apps")
        case .snapshots:       return String(localized: "APFS Snapshots")
        case .browsers:        return String(localized: "Browsers")
        case .python:          return String(localized: "Python")
        case .reviewRequired:  return String(localized: "Review Required")
        }
    }

    var systemImage: String {
        switch self {
        case .safeCleanup:     return "checkmark.shield"
        case .appCaches:       return "internaldrive"
        case .logs:            return "doc.text.magnifyingglass"
        case .developerJunk:   return "hammer"
        case .xcode:           return "hammer.circle"
        case .android:         return "iphone"
        case .gradle:          return "cube.box"
        case .arduino:         return "cpu"
        case .cursorIDE:       return "chevron.left.forwardslash.chevron.right"
        case .docker:          return "shippingbox"
        case .largeDownloads:  return "arrow.down.circle"
        case .largeFiles:      return "doc.viewfinder"
        case .localAIModels:   return "brain"
        case .applicationData: return "externaldrive.badge.questionmark"
        case .systemStorage:   return "laptopcomputer"
        case .trash:           return "trash"
        case .leftover:        return "shippingbox.and.arrow.backward"
        case .applications:    return "square.grid.2x2"
        case .snapshots:       return "clock.arrow.circlepath"
        case .browsers:        return "globe"
        case .python:          return "terminal"
        case .reviewRequired:  return "exclamationmark.triangle"
        }
    }

    /// Infer a category from a scanner / candidate id.
    nonisolated static func infer(scannerID: String) -> ScanCategory {
        let id = scannerID.lowercased()
        if id.hasPrefix("cursor") || id.hasPrefix("vscode") || id.hasPrefix("editor-ext")
            || id.contains("cachedextension") { return .cursorIDE }
        if id.hasPrefix("arduino") { return .arduino }
        if id.hasPrefix("docker") { return .docker }
        if id.hasPrefix("gradle") { return .gradle }
        if id.hasPrefix("android") || id.hasPrefix("avd") || id.hasPrefix("ndk") { return .android }
        if id.hasPrefix("xcode") || id.hasPrefix("device-support") || id.contains("deriveddata")
            || id.contains("coresimulator") { return .xcode }
        if id.hasPrefix("python") { return .python }
        if id.hasPrefix("aimodel") || id.contains("ondevicemodel") { return .localAIModels }
        if id.hasPrefix("log") || id.contains("user-logs") || id.contains("devicelogs") { return .logs }
        if id.hasPrefix("cache") || id.hasPrefix("syscache") { return .appCaches }
        if id.hasPrefix("trash") || id.contains(":trash") { return .trash }
        if id.hasPrefix("download") { return .largeDownloads }
        if id.hasPrefix("large-dir") || id.hasPrefix("largefile") { return .largeFiles }
        if id.hasPrefix("container") || id.hasPrefix("appsupport") { return .applicationData }
        if id.hasPrefix("devjunk") || id.hasPrefix("builtin:node") || id.hasPrefix("builtin:build") {
            return .developerJunk
        }
        if id.hasPrefix("leftover") { return .leftover }
        if id.hasPrefix("app:") { return .applications }
        if id.hasPrefix("apfs") { return .snapshots }
        if id.hasPrefix("browser") { return .browsers }
        if id.hasPrefix("homebrew") || id.hasPrefix("builtin:user-logs")
            || id.hasPrefix("builtin:trash") { return .safeCleanup }
        if id.hasPrefix("sys-") { return .systemStorage }
        return .reviewRequired
    }
}
