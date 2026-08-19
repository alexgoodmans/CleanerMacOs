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
        case .systemProtected:
            return .blocked("system protected — shown for size only")
        case .dangerous:
            return .blocked("dangerous — manual removal only")
        case .safe, .regeneratable, .reviewRequired:
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

    /// Smart Clean auto-selects only safe + regeneratable candidates whose path
    /// also passes the guard.
    nonisolated static func isSmartCleanEligible(_ candidate: CleanupCandidate) -> Bool {
        candidate.risk.isAutoSelectable && verdict(for: candidate).isAllowed
    }
}
