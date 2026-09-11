//
//  PathGuard.swift
//  Again Cleaner
//
//  The last line of defence before ANY deletion. Every path is canonicalized
//  (symlinks + `..` resolved) and checked against a deny-list of paths that may
//  never be removed, and an allow-list of roots cleanup is permitted to touch.
//
//  This is a backstop, not the selector: scanners decide *what* to offer, but
//  nothing is ever unlinked without PathGuard returning `.allowed` first.
//  Pure Foundation, `nonisolated`, safe to call from any thread.
//

import Foundation

enum PathGuard {

    nonisolated enum Verdict: Equatable, Sendable {
        case allowed
        case blocked(String)

        var isAllowed: Bool { if case .allowed = self { return true }; return false }
    }

    private nonisolated static let home =
        FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL

    /// Resolve symlinks AND collapse `..` / `.` so the check can't be fooled.
    nonisolated static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
    }

    /// Paths that must NEVER be deleted — as the target itself OR as a parent of
    /// one of these. Deleting them (or anything that contains them) is refused.
    nonisolated static var protectedPaths: Set<String> {
        var p: Set<String> = [
            "/", "/System", "/Library", "/usr", "/bin", "/sbin", "/etc", "/var",
            "/private", "/private/var", "/private/var/db", "/private/var/vm",
            "/private/var/folders", "/private/etc", "/opt", "/cores",
            "/Applications", "/Users", "/Volumes", "/Network",
            "/System/Volumes", "/System/Volumes/Data",
        ]
        let h = home.path
        // The home dir itself and its sensitive top-level folders: children may
        // be cleaned, the folders themselves never removed wholesale.
        let sensitive = [
            "", "/Library", "/Library/Keychains", "/Library/Application Support",
            "/Library/Containers", "/Library/Group Containers",
            "/Library/Mobile Documents", "/Library/Mail", "/Library/Messages",
            "/Library/Preferences", "/Library/CloudStorage",
            // Cleanup happens on the CHILDREN of these; the folders themselves
            // must never be removed wholesale.
            "/Library/Caches", "/Library/Logs", "/Library/Developer",
            "/Documents", "/Desktop", "/Downloads", "/Pictures", "/Movies", "/Music",
        ]
        for s in sensitive { p.insert(h + s) }
        return p
    }

    /// Roots inside which deletion is permitted. A canonical path must live
    /// strictly *under* one of these (never equal to it) to be allowed.
    nonisolated static var allowedRoots: [String] {
        let h = home.path
        return [
            h + "/Library", h + "/.Trash",
            h + "/.gradle", h + "/.npm", h + "/.cursor", h + "/.espressif",
            h + "/.bun", h + "/.android", h + "/.nuget", h + "/.conan2",
            h + "/.vscode", h + "/go", h + "/Downloads", h + "/Desktop",
            h,                                    // build artifacts live anywhere in home
            "/Library/Caches", "/Library/Logs",
            "/private/var/tmp", "/private/var/folders",
            "/Applications",
        ]
    }

    // MARK: - Hard credential/key block (unconditional, checked before anything else)
    //
    // This is defense in depth against a scanner ever misclassifying a
    // credential as junk: no risk level, no allow-list membership, and no
    // future scanner bug can bypass this. It matches by path COMPONENT and
    // file name, so it also catches files nested arbitrarily deep inside an
    // otherwise-allowed root (e.g. the contents of ~/Library/Keychains, which
    // the exact-path deny-list above does not reach).

    /// Directory names that are never touched, anywhere they occur.
    nonisolated static let sensitiveDirNames: Set<String> = [
        ".ssh", ".gnupg", ".gnupg2", ".aws", ".kube", ".azure", ".docker",
        ".terraform.d", ".vault", ".minikube", "Keychains", ".ssh-agent",
        ".gcloud", ".config",
    ]

    /// Exact file names that are never touched, anywhere they occur.
    nonisolated static let sensitiveFileNames: Set<String> = [
        ".netrc", ".npmrc", ".yarnrc", ".pgpass", ".git-credentials",
        "id_rsa", "id_ed25519", "id_ecdsa", "id_dsa", "authorized_keys",
        "known_hosts", "credentials", "credentials.json",
    ]

    /// File-name suffixes that are never touched, anywhere they occur.
    nonisolated static let sensitiveFileSuffixes: [String] = [
        ".pem", ".key", ".p12", ".pfx", ".jks", ".keystore", ".ovpn",
        ".kdbx", ".keychain", ".keychain-db", ".gpg", ".asc",
    ]

    /// nil when `url` is not credential-shaped; otherwise the reason it's blocked.
    nonisolated static func sensitiveReason(for url: URL) -> String? {
        for component in url.pathComponents where sensitiveDirNames.contains(component) {
            return "refusing to touch a credentials/keys directory (\(component))"
        }
        let name = url.lastPathComponent
        if sensitiveFileNames.contains(name) {
            return "refusing to touch a credentials file (\(name))"
        }
        let lower = name.lowercased()
        if sensitiveFileSuffixes.contains(where: { lower.hasSuffix($0) }) {
            return "refusing to touch a key/credential file (\(name))"
        }
        return nil
    }

    /// The verdict for deleting `url`. `.allowed` only when the canonical path
    /// is safe on every count.
    nonisolated static func verdict(for url: URL) -> Verdict {
        // Unconditional first: nothing below can ever override this.
        if let reason = sensitiveReason(for: url) {
            return .blocked(reason)
        }

        let path = canonicalPath(url)

        if path == "/" { return .blocked("cannot remove the filesystem root") }
        if path.isEmpty { return .blocked("empty path") }

        let protected = protectedPaths
        if protected.contains(path) {
            return .blocked("protected system path: \(path)")
        }
        // Is `path` an ANCESTOR of something protected? (e.g. deleting "/Users")
        for prot in protected where prot.hasPrefix(path + "/") {
            return .blocked("would remove a parent of protected path: \(prot)")
        }

        // Must sit strictly under an allowed root (this also defeats symlink
        // escapes, since we canonicalized first).
        let roots = allowedRoots
        if roots.contains(path) {
            return .blocked("cannot remove a cleanup root itself: \(path)")
        }
        guard roots.contains(where: { path.hasPrefix($0 + "/") }) else {
            return .blocked("outside allowed cleanup roots: \(path)")
        }

        return .allowed
    }

    /// Convenience: throws-free bool.
    nonisolated static func isDeletable(_ url: URL) -> Bool {
        verdict(for: url).isAllowed
    }

    /// True when `child` is strictly inside `parent` after canonicalization.
    nonisolated static func isStrictChild(_ child: URL, of parent: URL) -> Bool {
        let c = canonicalPath(child)
        let p = canonicalPath(parent)
        return c != p && c.hasPrefix(p + "/")
    }
}
