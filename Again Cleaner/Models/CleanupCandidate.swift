//
//  CleanupCandidate.swift
//  Again Cleaner
//
//  Phase-0 foundation for the smart-analyzer rewrite. These types live
//  ALONGSIDE the existing `Safety` / `JunkCategory` model — nothing here
//  replaces the current, working cleanup path yet. A bridge from the old
//  3-level `Safety` to the new 5-level `CleanupRisk` keeps both in sync.
//

import Foundation
import SwiftUI

// MARK: - Risk

/// Five-level classification driving what Smart Clean may touch automatically.
nonisolated enum CleanupRisk: Int, Comparable, Codable, Sendable, CaseIterable {
    case safe            // logs, trash — always fine to remove automatically
    case regeneratable   // caches/build data — removed, app/IDE recreates it
    case reviewRequired  // user must look inside before deleting
    case dangerous       // never deleted automatically (device backups…)
    case systemProtected // shown for size only — no delete button at all

    static func < (l: CleanupRisk, r: CleanupRisk) -> Bool { l.rawValue < r.rawValue }

    /// Smart Clean auto-selects only these.
    var isAutoSelectable: Bool { self == .safe || self == .regeneratable }

    /// Whether the app is ever allowed to delete this at all.
    var isDeletable: Bool { self != .systemProtected }

    var label: String {
        switch self {
        case .safe:            return String(localized: "Safe")
        case .regeneratable:   return String(localized: "Regeneratable")
        case .reviewRequired:  return String(localized: "Review Required")
        case .dangerous:       return String(localized: "Dangerous")
        case .systemProtected: return String(localized: "System Protected")
        }
    }

    var tint: Color {
        switch self {
        case .safe:            return .green
        case .regeneratable:   return .teal
        case .reviewRequired:  return .orange
        case .dangerous:       return .red
        case .systemProtected: return .secondary
        }
    }
}

// MARK: - Bridge from the existing 3-level Safety

extension Safety {
    /// Map the current model onto the new risk scale so both can coexist while
    /// the analyzer is built out. Most `caution` categories are regeneratable
    /// caches; `risky` ones are the "look before you leap" kind.
    var risk: CleanupRisk {
        switch self {
        case .safe:    return .safe
        case .caution: return .regeneratable
        case .risky:   return .reviewRequired
        }
    }
}

// MARK: - Cleanup method

/// How a candidate is actually cleaned. The executor dispatches on this instead
/// of assuming everything is a filesystem delete.
nonisolated enum CleanupMethod: Sendable, Equatable {
    case filesystem           // FileManager remove / trash
    case dockerBuilderPrune   // `docker builder prune -f` via ProcessRunner
    case dockerVolumeRemove   // `docker volume rm <name>` — one specific volume
    case homebrewCleanup      // `brew cleanup`
    case tmutil               // APFS snapshot thinning
    case manualOnly           // shown, but only the user can act (Reveal in Finder)
}

// MARK: - Candidate

/// One concrete thing the analyzer found: what it is, how big, how risky, and
/// how it should be cleaned. Produced by scanners, consumed by the UI + executor.
nonisolated struct CleanupCandidate: Identifiable, Sendable {
    let id: UUID
    let scannerID: String        // which scanner produced it
    let name: String
    let path: URL?               // nil for non-filesystem items (e.g. Docker cache)
    let size: Int64
    let risk: CleanupRisk
    let explanation: String      // "what this is"
    let consequence: String      // "what happens after you remove it"
    let lastModified: Date?
    let method: CleanupMethod

    init(
        id: UUID = UUID(),
        scannerID: String,
        name: String,
        path: URL?,
        size: Int64,
        risk: CleanupRisk,
        explanation: String,
        consequence: String,
        lastModified: Date? = nil,
        method: CleanupMethod = .filesystem
    ) {
        self.id = id
        self.scannerID = scannerID
        self.name = name
        self.path = path
        self.size = size
        self.risk = risk
        self.explanation = explanation
        self.consequence = consequence
        self.lastModified = lastModified
        self.method = method
    }
}
