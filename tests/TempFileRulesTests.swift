import Foundation

/// Which /tmp entries may be offered — live sockets, other users' files and
/// IPC names must never be.
@main
enum TempFileRulesTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func check(_ ok: Bool, _ label: String) {
            if ok { pass += 1; print("  ✓ \(label)") } else { fail += 1; print("  ✗ FAIL \(label)") }
        }

        let me = getuid()
        let now = Date()
        let day: TimeInterval = 86_400
        func item(_ name: String, _ kind: TempFileRules.Kind, uid: uid_t? = nil,
                  age: TimeInterval? = 5 * 86_400, socket: Bool = false) -> TempFileRules.Item {
            TempFileRules.Item(url: URL(fileURLWithPath: "/private/tmp/" + name), kind: kind,
                               ownerUID: uid ?? me,
                               newestModified: age.map { now.addingTimeInterval(-$0) },
                               containsSocket: socket)
        }
        func verdict(_ i: TempFileRules.Item) -> TempFileRules.Verdict {
            TempFileRules.classify(i, currentUID: me, now: now)
        }
        func skipped(_ i: TempFileRules.Item) -> Bool {
            if case .skip = verdict(i) { return true }; return false
        }

        print("Never offered:")
        check(skipped(item("Cursor-abc.sock", .socket)), "live socket")
        check(skipped(item("pipe", .fifo)), "named pipe")
        check(skipped(item("link", .symlink)), "symlink")
        check(skipped(item("theirs", .directory, uid: 0)), "owned by another user (root)")
        check(skipped(item("com.apple.launchd.ABC", .directory)), "com.apple.launchd.* (ssh-agent socket dir)")
        check(skipped(item("tmux-501", .directory)), "tmux socket dir")
        check(skipped(item("mysql.sock", .file)), "*.sock name even as a regular file")
        check(skipped(item("server.pid", .file)), "*.pid")
        check(skipped(item("build.lock", .file)), "*.lock")
        check(skipped(item("project", .directory, socket: true)), "folder containing a live socket")

        print("Age decides the risk:")
        check(verdict(item("old.log", .file, age: 5 * day)) == .old, "untouched 5 days → old")
        check(verdict(item("edge.log", .file, age: 3 * day)) == .old, "exactly 3 days → old")
        check(verdict(item("fresh.log", .file, age: 3600)) == .recent, "changed 1 h ago → recent")
        check(verdict(item("unknown", .directory, age: nil)) == .recent, "unknown age → recent (maybe in use)")

        print("Real filesystem:")
        let fm = FileManager.default
        let root = "/private/tmp/tfr-\(getpid())"
        try? fm.removeItem(atPath: root)
        try? fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(atPath: root) }
        let old = now.addingTimeInterval(-5 * day)
        func touch(_ path: String, _ date: Date) { try? fm.setAttributes([.modificationDate: date], ofItemAtPath: path) }

        fm.createFile(atPath: root + "/oldfile", contents: Data("x".utf8)); touch(root + "/oldfile", old)
        fm.createFile(atPath: root + "/newfile", contents: Data("x".utf8))
        try? fm.createDirectory(atPath: root + "/olddir", withIntermediateDirectories: true)
        fm.createFile(atPath: root + "/olddir/a", contents: Data("x".utf8)); touch(root + "/olddir/a", old)
        touch(root + "/olddir", old)
        try? fm.createDirectory(atPath: root + "/mixeddir", withIntermediateDirectories: true)
        fm.createFile(atPath: root + "/mixeddir/recent", contents: Data("x".utf8))
        touch(root + "/mixeddir", old)   // folder looks old, but something inside is fresh
        try? fm.createDirectory(atPath: root + "/com.apple.test", withIntermediateDirectories: true)
        touch(root + "/com.apple.test", old)
        fm.createFile(atPath: root + "/x.sock", contents: Data()); touch(root + "/x.sock", old)
        try? fm.createSymbolicLink(atPath: root + "/link", withDestinationPath: "/usr")
        try? fm.createDirectory(atPath: root + "/sockdir", withIntermediateDirectories: true)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un(); addr.sun_family = sa_family_t(AF_UNIX)
        let sockPath = root + "/sockdir/live"
        _ = withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            sockPath.utf8CString.withUnsafeBytes { memcpy(buf.baseAddress, $0.baseAddress, min(buf.count - 1, $0.count)) }
        }
        _ = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        defer { close(fd) }
        touch(root + "/sockdir", old)

        let found = Dictionary(uniqueKeysWithValues:
            TempFileRules.candidates(in: URL(fileURLWithPath: root), now: now).map { ($0.item.name, $0.verdict) })
        check(found["oldfile"] == .old, "old file → old")
        check(found["newfile"] == .recent, "new file → recent")
        check(found["olddir"] == .old, "folder untouched inside → old")
        check(found["mixeddir"] == .recent, "old folder with a fresh file inside → recent (newest inside counts)")
        check(found["sockdir"] == nil, "folder with a live socket inside → not offered")
        check(found["com.apple.test"] == nil, "com.apple.* → not offered")
        check(found["x.sock"] == nil, "*.sock → not offered")
        check(found["link"] == nil, "symlink → not offered")
        check(TempFileRules.inspect(URL(fileURLWithPath: sockPath)).kind == .socket, "inspect recognises a real socket")

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
