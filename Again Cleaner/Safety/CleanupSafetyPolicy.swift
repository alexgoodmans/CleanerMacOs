//
//  CleanupSafetyPolicy.swift
//  Again Cleaner
//
//  Combines the risk level with PathGuard into a single yes/no gate the
//  executor consults before touching anything. Risk decides intent
//  (systemProtected/dangerous are never auto-removed); PathGuard decides the
//  path is physically safe to unlink.
//

import Foundation

enum CleanupSafetyPolicy {

    /// Whether a candidate may be deleted right now, by the app.
    nonisolated static func verdict(for candidate: CleanupCandidate) -> PathGuard.Verdict {
        switch candidate.risk {
        case .neverDeleteAutomatically:
            return .blocked("never auto-delete — shown for size only")
        case .dangerous:
            return .blocked("dangerous — manual removal only")
        case .safe, .usuallySafe, .reviewRequired:
            break
        }

        // Non-filesystem methods (Docker/brew/tmutil) don't touch a path
        // directly — the tool enforces its own safety. Only guard real paths.
        guard candidate.method == .filesystem else { return .allowed }

        guard let url = candidate.path else {
            return .blocked("filesystem candidate without a path")
        }
        return PathGuard.verdict(for: url)
    }

    /// Eligible for the explicit "Select Safe" action / Quick Clean preset —
    /// both require the user to review the preview sheet before anything is
    /// actually removed.
    nonisolated static func isSmartCleanEligible(_ candidate: CleanupCandidate) -> Bool {
        candidate.risk.isAutoSelectable && verdict(for: candidate).isAllowed
    }

    /// What gets ticked automatically the instant a scan finishes, with no
    /// user action at all. Deliberately much narrower than `isSmartCleanEligible`
    /// — only the least ambiguous risk tier, and still gated by PathGuard.
    nonisolated static func isPreselected(_ candidate: CleanupCandidate) -> Bool {
        candidate.risk.isPreselectedByDefault && verdict(for: candidate).isAllowed
    }
}
