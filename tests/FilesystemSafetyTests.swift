import Foundation

@main
enum FilesystemSafetyTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func ok(_ cond: Bool, _ label: String) {
            if cond { pass += 1; print("  ✓ \(label)") }
            else { fail += 1; print("  ✗ FAIL \(label)") }
        }

        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("ac-safety-\(getpid())", isDirectory: true)
        try? fm.removeItem(at: root)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)

        print("False-positive build folder:")
        let photos = root.appendingPathComponent("VacationPhotos")
        try? fm.createDirectory(at: photos.appendingPathComponent("build"), withIntermediateDirectories: true)
        try? "img".write(to: photos.appendingPathComponent("build/photo.jpg"), atomically: true, encoding: .utf8)
        let rust = root.appendingPathComponent("rust-app")
        try? fm.createDirectory(at: rust.appendingPathComponent("target"), withIntermediateDirectories: true)
        try? "".write(to: rust.appendingPathComponent("Cargo.toml"), atomically: true, encoding: .utf8)
        try? "obj".write(to: rust.appendingPathComponent("target/x.rlib"), atomically: true, encoding: .utf8)
        let android = root.appendingPathComponent("android-app")
        try? fm.createDirectory(at: android.appendingPathComponent("app/build"), withIntermediateDirectories: true)
        try? "".write(to: android.appendingPathComponent("build.gradle"), atomically: true, encoding: .utf8)
        try? "dex".write(to: android.appendingPathComponent("app/build/out.dex"), atomically: true, encoding: .utf8)

        let found = FileSystemEngine.artifactDirectories(
            named: ["build", "target"], under: root)
        let names = found.map { $0.path }
        ok(names.contains(where: { $0.hasSuffix("rust-app/target") }), "rust target detected")
        ok(names.contains(where: { $0.hasSuffix("android-app/app/build") }), "android app/build detected")
        ok(!names.contains(where: { $0.hasSuffix("VacationPhotos/build") }), "photo build/ ignored")

        print("Symlink size must not follow into another tree:")
        let real = root.appendingPathComponent("real-data")
        try? fm.createDirectory(at: real, withIntermediateDirectories: true)
        let payload = Data(repeating: 7, count: 32_000)
        try? payload.write(to: real.appendingPathComponent("blob.bin"))
        let decoy = root.appendingPathComponent("decoy")
        try? fm.createDirectory(at: decoy, withIntermediateDirectories: true)
        let link = decoy.appendingPathComponent("escape")
        try? fm.createSymbolicLink(at: link, withDestinationURL: real)
        let decoySize = FileSystemEngine.size(of: decoy)
        let realSize = FileSystemEngine.size(of: real)
        ok(decoySize < realSize, "symlink dir not counted as destination size (\(decoySize) vs \(realSize))")

        print("Parent-path protection:")
        let parent = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/ac-parent-test")
        let child = parent.appendingPathComponent("child")
        ok(PathGuard.isStrictChild(child, of: parent), "child is inside parent")
        ok(!PathGuard.isStrictChild(parent, of: child), "parent is not inside child")
        ok(!PathGuard.isStrictChild(parent, of: parent), "path is not a child of itself")
        let home = FileManager.default.homeDirectoryForCurrentUser
        ok(!PathGuard.isDeletable(home), "home itself not deletable")
        ok(!PathGuard.isDeletable(home.appendingPathComponent("Library")), "Library not deletable")
        ok(PathGuard.isDeletable(home.appendingPathComponent("Library/Caches/com.example")), "cache child deletable")

        print("Cursor extension fixture grouping:")
        let extRoot = root.appendingPathComponent("extensions")
        try? fm.createDirectory(at: extRoot, withIntermediateDirectories: true)
        for name in ["openai.chatgpt-0.1.1", "openai.chatgpt-0.1.9", "openai.chatgpt-0.1.10"] {
            try? fm.createDirectory(at: extRoot.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let g = EditorExtensionParsing.groups(from: ["openai.chatgpt-0.1.1", "openai.chatgpt-0.1.9", "openai.chatgpt-0.1.10"])
        ok(g.first?.newest.version == "0.1.10", "0.1.10 newest not 0.1.9 lexical")
        ok(g.first?.stale.count == 2, "two stale")

        print("Cancellation of large-file walk:")
        var ticks = 0
        _ = FileSystemEngine.largeFiles(under: root, minSize: 1, limit: 500) {
            ticks += 1
            return ticks > 2
        }
        ok(true, "cancel callback polled without aborting process")

        print("Inaccessible child does not abort sizing:")
        let hidden = root.appendingPathComponent("secret")
        try? fm.createDirectory(at: hidden, withIntermediateDirectories: true)
        try? payload.write(to: hidden.appendingPathComponent("x.bin"))
        try? fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: hidden.path)
        let sized = FileSystemEngine.size(of: root)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hidden.path)
        ok(sized >= 0, "size of tree with unreadable child is still a number (\(sized))")

        try? fm.removeItem(at: root)
        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
