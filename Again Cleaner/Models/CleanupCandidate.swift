//
//  CleanupCandidate.swift
//  Again Cleaner
//
//  One concrete thing a scanner found: what it is, how big, how risky, and
//  how it should be cleaned. Produced by scanners, consumed by the UI + executor.
//

import Foundation
import SwiftUI

// MARK: - Risk

/// Five-level classification driving what Smart Clean may touch automatically.
/// Spec names: safe / usuallySafe / reviewRequired / dangerous / neverDeleteAutomatically.
nonisolated enum CleanupRisk: Int, Comparable, Codable, Sendable, CaseIterable {
    case safe                      // logs, trash — always fine to remove automatically
    case usuallySafe               // caches/build data — removed, app/IDE recreates it
    case reviewRequired            // user must look inside before deleting
    case dangerous                 // never deleted automatically (device backups…)
    case neverDeleteAutomatically  // shown for size only — no delete button at all

    static func < (l: CleanupRisk, r: CleanupRisk) -> Bool { l.rawValue < r.rawValue }

    /// Eligible for the explicit "Select Safe" action and the Quick Clean
    /// preset — both are actions the user deliberately triggers and confirms
    /// via the preview sheet, never something that fires silently.
    var isAutoSelectable: Bool { self == .safe || self == .usuallySafe }

    /// True only for the narrowest, least ambiguous tier (logs, trash).
    /// This is the ONLY thing ticked automatically the moment a scan finishes
    /// — "usually safe" caches are still a guess by a scanner heuristic, and a
    /// wrong guess here is exactly what caused real data loss. The user must
    /// explicitly opt into anything beyond `.safe`, every time.
    var isPreselectedByDefault: Bool { self == .safe }

    /// Whether the app is ever allowed to delete this at all.
    var isDeletable: Bool { self != .neverDeleteAutomatically && self != .dangerous }

    var label: String {
        switch self {
        case .safe:                     return String(localized: "Safe")
        case .usuallySafe:              return String(localized: "Usually Safe")
        case .reviewRequired:           return String(localized: "Review Required")
        case .dangerous:                return String(localized: "Dangerous")
        case .neverDeleteAutomatically: return String(localized: "Never Auto-Delete")
        }
    }

    var tint: Color {
        switch self {
        case .safe:                     return .green
        case .usuallySafe:              return .teal
        case .reviewRequired:           return .orange
        case .dangerous:                return .red
        case .neverDeleteAutomatically: return .secondary
        }
    }

    /// A longer, honest explanation of what this tier actually means and what
    /// could go wrong — shown as a tooltip / detail popover on every item.
    /// Written after a real incident where "usually safe" turned out to not be
    /// safe enough for some cached credentials, so it says so plainly.
    var detail: String {
        switch self {
        case .safe:
            return String(localized: "Confirmed disposable — logs, crash reports, trash. Selected automatically. Nothing an app needs to keep running is ever put here.")
        case .usuallySafe:
            return String(localized: "A cache folder that MOST apps regenerate automatically — but this is a heuristic guess based on where the file lives, not a guarantee about what's inside it. Some tools misuse cache folders to store tokens or session data. Never pre-selected — you choose to include it.")
        case .reviewRequired:
            return String(localized: "Likely holds real data: settings, history, a database, or something the app can't simply redownload. Look at the path before removing.")
        case .dangerous:
            return String(localized: "Can hold data with no automatic backup elsewhere (e.g. a Docker volume with a database). Again Cleaner never deletes this automatically — remove it yourself, deliberately, if you're sure.")
        case .neverDeleteAutomatically:
            return String(localized: "Shown only so you can see what's using space. There is no delete button for this risk tier — removal, if any, is manual and outside Again Cleaner.")
        }
    }
}

// MARK: - Bridge from the existing 3-level Safety

extension Safety {
    /// Map the catalog's 3-level model onto the 5-level risk scale.
    nonisolated var risk: CleanupRisk {
        switch self {
        case .safe:    return .safe
        case .caution: return .usuallySafe
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
    case dockerImagePrune     // `docker image prune -f` — dangling images only
    case dockerVolumeRemove   // `docker volume rm <name>` — one specific volume
    case homebrewCleanup      // `brew cleanup`
    case tmutil               // APFS snapshot thinning
    case manualOnly           // shown, but only the user can act (Reveal in Finder)
}

// MARK: - Candidate

/// One concrete thing the analyzer found.
nonisolated struct CleanupCandidate: Identifiable, Sendable {
    let id: UUID
    let scannerID: String
    let name: String
    let path: URL?
    let size: Int64
    let reclaimableBytes: Int64
    let risk: CleanupRisk
    let category: ScanCategory
    let subcategory: String?
    let developer: String?
    let confidence: ScanConfidence
    let isRegenerable: Bool
    let requiresAdmin: Bool
    let explanation: String
    let consequence: String
    let recoveryDescription: String
    let lastModified: Date?
    let lastAccessed: Date?
    let method: CleanupMethod
    let accessState: ScanAccessState

    /// Whether the UI should offer a checkbox.
    var canUserDelete: Bool {
        risk.isDeletable && method != .manualOnly && accessState == .scanned
    }

    /// Whether this item's size should roll into Safe / Review totals.
    var contributesToTotals: Bool {
        accessState == .scanned && size > 0
    }

    init(
        id: UUID = UUID(),
        scannerID: String,
        name: String,
        path: URL?,
        size: Int64,
        reclaimableBytes: Int64? = nil,
        risk: CleanupRisk,
        category: ScanCategory? = nil,
        subcategory: String? = nil,
        developer: String? = nil,
        confidence: ScanConfidence = .high,
        isRegenerable: Bool? = nil,
        requiresAdmin: Bool = false,
        explanation: String,
        consequence: String,
        recoveryDescription: String? = nil,
        lastModified: Date? = nil,
        lastAccessed: Date? = nil,
        method: CleanupMethod = .filesystem,
        accessState: ScanAccessState = .scanned
    ) {
        self.id = id
        self.scannerID = scannerID
        self.name = name
        self.path = path
        self.size = size
        self.reclaimableBytes = reclaimableBytes ?? size
        self.risk = risk
        self.category = category ?? ScanCategory.infer(scannerID: scannerID)
        self.subcategory = subcategory
        self.developer = developer
        self.confidence = confidence
        self.isRegenerable = isRegenerable ?? (risk == .safe || risk == .usuallySafe)
        self.requiresAdmin = requiresAdmin
        self.explanation = explanation
        self.consequence = consequence
        self.recoveryDescription = recoveryDescription ?? consequence
        self.lastModified = lastModified
        self.lastAccessed = lastAccessed
        self.method = method
        self.accessState = accessState
    }
}
