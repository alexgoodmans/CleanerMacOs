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
        let path = url.standardizedFileURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        // resolvingSymlinksInPath() deliberately STRIPS a leading /private
        // (/private/tmp/x → /tmp/x). Re-add it so every path into /tmp, /var
        // and /etc has exactly one spelling — otherwise "/private/tmp/…"
        // rules and roots silently never match.
        for top in ["/tmp", "/var", "/etc"] where path == top || path.hasPrefix(top + "/") {
            return "/private" + path
        }
        return path
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
            // /tmp itself stays protected (a root is never removed); which of
            // its entries are offered is decided by TempFileRules. (No other
            // /private/var roots: nothing cleans there, and before paths were
            // normalised below such entries never matched anyway.)
            "/private/tmp",
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

        // Same check on the RESOLVED path: a symlink of any name that leads
        // into Keychains/.ssh/… is still a credential store.
        if let reason = sensitiveReason(for: URL(fileURLWithPath: path)) {
            return .blocked(reason)
        }
        if let reason = appleContainerReason(path) { return .blocked(reason) }

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

        // A socket or named pipe is a live endpoint of a running process —
        // never junk, wherever it is.
        var st = stat()
        if lstat(path, &st) == 0 {
            let type = st.st_mode & S_IFMT
            if type == S_IFSOCK || type == S_IFIFO {
                return .blocked("refusing to remove a live socket / pipe: \(path)")
            }
        }

        if let reason = tempEntryReason(path) { return .blocked(reason) }

        return .allowed
    }

    /// macOS's own app containers (Mail, Safari, Messages, Notes, Photos…) hold
    /// irreplaceable data and symlinks back into ~/Library — Keychains,
    /// Preferences, Fonts. Nothing inside them is touched except the few
    /// regenerable spots listed below. For ANY container, the container
    /// itself and its Data / Data/Library skeleton are never removed.
    nonisolated static func appleContainerReason(_ canonical: String) -> String? {
        let h = home.path
        for base in [h + "/Library/Containers/", h + "/Library/Group Containers/"]
        where canonical.hasPrefix(base) {
            let rest = canonical.dropFirst(base.count).split(separator: "/").map(String.init)
            guard let name = rest.first else { return nil }

            if rest.count == 1 || rest[1...] == ["Data"] || rest[1...] == ["Data", "Library"] {
                return "refusing to remove an app container skeleton: \(canonical)"
            }
            let isApple = name.hasPrefix("com.apple.") || name.hasPrefix("group.com.apple.")
                || name.contains(".com.apple.") || name == "com.apple"
            guard isApple else { return nil }

            // Strictly inside Data/Library/Caches, or Mail's attachment cache.
            let inner = Array(rest.dropFirst())
            let regenerable: [[String]] = [["Data", "Library", "Caches"],
                                           ["Data", "Library", "Mail Downloads"]]
            if regenerable.contains(where: { inner.count > $0.count && Array(inner.prefix($0.count)) == $0 }) {
                return nil
            }
            return "refusing to touch macOS's own app container: \(name)"
        }
        return nil
    }

    /// Inside the shared /tmp, anything may only be removed if its top-level
    /// entry is one TempFileRules would offer: the user's own regular file or
    /// folder, no system/IPC name, no socket inside. This holds even for paths
    /// that reach here without a scanner — e.g. /tmp pinned as a Favorite and
    /// emptied wholesale. Age is not checked here: a recent item the user
    /// explicitly confirmed may go.
    nonisolated static func tempEntryReason(_ canonical: String) -> String? {
        let tmp = "/private/tmp/"
        guard canonical.hasPrefix(tmp),
              let top = canonical.dropFirst(tmp.count).split(separator: "/").first else { return nil }
        let item = TempFileRules.inspect(URL(fileURLWithPath: tmp + top))
        if case .skip(let why) = TempFileRules.classify(item, currentUID: getuid(),
                                                         now: Date(), minAgeDays: 0) {
            return "refusing to touch /tmp entry \(top): \(why)"
        }
        return nil
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
