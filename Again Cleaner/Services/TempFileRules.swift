//
//  TempFileRules.swift
//  Again Cleaner
//
//  Which top-level entries of /tmp (/private/tmp) may be offered for cleanup.
//
//  /tmp is shared, live space — not a cache. On a real machine it held 34
//  live IPC sockets (Cursor), ssh-agent / launchd sockets under
//  com.apple.launchd.*, root-owned items, and the working directory of a
//  running Claude Code session. Removing any of those breaks a running app.
//  So an entry is only ever offered when it is:
//   • a regular file or directory (never a socket, FIFO, symlink, device),
//   • owned by the current user,
//   • not a known system/IPC name (com.apple.*, tmux-*, ssh-*, *.sock, *.pid…),
//   • a directory with no socket anywhere inside it.
//  Age then decides the risk: nothing changed anywhere inside for
//  `defaultMinAgeDays` (macOS's own periodic /tmp cleaner uses 3) → old;
//  anything newer → recent, i.e. possibly still in use.
//

import Foundation
import Darwin

enum TempFileRules {

    nonisolated static let defaultMinAgeDays = 3

    /// Never offered, regardless of owner or age.
    nonisolated static let protectedPrefixes: [String] = [
        "com.apple.",            // launchd / ssh-agent sockets (SSH_AUTH_SOCK lives here)
        ".X11-unix", ".ICE-unix", ".font-unix", ".XIM-unix", ".Test-unix",
        "tmux-", "screen-", "ssh-", "launchd-", "powerlog",
    ]
    nonisolated static let protectedSuffixes: [String] = [
        ".sock", ".socket", ".pid", ".lock", ".lck",
    ]

    nonisolated static func isProtectedName(_ name: String) -> Bool {
        protectedPrefixes.contains { name.hasPrefix($0) }
            || protectedSuffixes.contains { name.lowercased().hasSuffix($0) }
    }

    nonisolated enum Kind: Sendable, Equatable {
        case file, directory, socket, fifo, symlink, other
    }

    nonisolated struct Item: Sendable {
        let url: URL
        let kind: Kind
        let ownerUID: uid_t
        /// Newest modification anywhere inside (the entry itself for files);
        /// nil when it couldn't be determined (treated as possibly in use).
        let newestModified: Date?
        let containsSocket: Bool
        var name: String { url.lastPathComponent }
    }

    nonisolated enum Verdict: Sendable, Equatable {
        case skip(String)   // never offered — the reason is for logs/tests
        case old            // untouched long enough → usually safe
        case recent         // changed recently → may be in use, review
    }

    nonisolated static func classify(
        _ item: Item, currentUID: uid_t, now: Date, minAgeDays: Int = defaultMinAgeDays
    ) -> Verdict {
        switch item.kind {
        case .socket:  return .skip("live socket")
        case .fifo:    return .skip("named pipe")
        case .symlink: return .skip("symlink")
        case .other:   return .skip("special file")
        case .file, .directory: break
        }
        if item.ownerUID != currentUID { return .skip("owned by another user") }
        if isProtectedName(item.name) { return .skip("system / IPC name") }
        if item.containsSocket { return .skip("contains a live socket") }
        guard let newest = item.newestModified else { return .recent }
        let age = now.timeIntervalSince(newest)
        return age >= Double(minAgeDays) * 86_400 ? .old : .recent
    }

    // MARK: - Inspecting the filesystem

    /// lstat the entry and, for a directory, walk it (bounded) for the newest
    /// modification and any socket. Never follows symlinks.
    nonisolated static func inspect(_ url: URL, walkLimit: Int = 50_000) -> Item {
        var st = stat()
        guard lstat(url.path, &st) == 0 else {
            return Item(url: url, kind: .other, ownerUID: uid_t.max,
                        newestModified: nil, containsSocket: false)
        }
        let kind = Self.kind(of: st.st_mode)
        var newest: Date? = date(st.st_mtimespec)
        var socket = false

        if kind == .directory, let root = strdup(url.path) {
            defer { free(root) }
            var argv: [UnsafeMutablePointer<CChar>?] = [root, nil]
            if let fts = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR, nil) {
                defer { fts_close(fts) }
                var visited = 0
                while let entry = fts_read(fts) {
                    visited += 1
                    if visited > walkLimit { newest = nil; break }   // too big to be sure → "recent"
                    guard let s = entry.pointee.fts_statp?.pointee else { continue }
                    if Self.kind(of: s.st_mode) == .socket || Self.kind(of: s.st_mode) == .fifo {
                        socket = true
                        break
                    }
                    if let d = date(s.st_mtimespec), let current = newest, d > current {
                        newest = d
                    }
                }
            } else {
                newest = nil
            }
        }
        return Item(url: url, kind: kind, ownerUID: st.st_uid,
                    newestModified: newest, containsSocket: socket)
    }

    /// Every offerable top-level entry of `dir` with its verdict (skips dropped).
    nonisolated static func candidates(
        in dir: URL, now: Date = Date(), minAgeDays: Int = defaultMinAgeDays
    ) -> [(item: Item, verdict: Verdict)] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        let uid = getuid()
        return names.compactMap { name in
            let item = inspect(dir.appendingPathComponent(name))
            let verdict = classify(item, currentUID: uid, now: now, minAgeDays: minAgeDays)
            if case .skip = verdict { return nil }
            return (item, verdict)
        }
    }

    private nonisolated static func kind(of mode: mode_t) -> Kind {
        switch mode & S_IFMT {
        case S_IFREG:  return .file
        case S_IFDIR:  return .directory
        case S_IFSOCK: return .socket
        case S_IFIFO:  return .fifo
        case S_IFLNK:  return .symlink
        default:       return .other
        }
    }

    private nonisolated static func date(_ ts: timespec) -> Date? {
        Date(timeIntervalSince1970: Double(ts.tv_sec) + Double(ts.tv_nsec) / 1e9)
    }
}
