import Foundation

@main
enum LeftoverMatchingTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func ok(_ cond: Bool, _ label: String) {
            if cond { pass += 1; print("  ✓ \(label)") }
            else { fail += 1; print("  ✗ FAIL \(label)") }
        }

        print("Bundle-identifier recognition:")
        ok(LeftoverMatching.isBundleIdentifier("com.google.Chrome"), "com.google.Chrome")
        ok(LeftoverMatching.isBundleIdentifier("com.foo.bar-baz_2"), "url-safe segments")
        ok(!LeftoverMatching.isBundleIdentifier("Spotify"), "plain name rejected")
        ok(!LeftoverMatching.isBundleIdentifier("My App"), "name with space rejected")
        ok(!LeftoverMatching.isBundleIdentifier("com."), "trailing dot rejected")
        ok(!LeftoverMatching.isBundleIdentifier(".com.foo"), "leading dot rejected")

        print("File-name → bundle id:")
        ok(LeftoverMatching.bundleID(fromFileName: "com.foo.Bar.plist") == "com.foo.Bar", "strip .plist")
        ok(LeftoverMatching.bundleID(fromFileName: "com.foo.Bar.savedState") == "com.foo.Bar", "strip .savedState")
        ok(LeftoverMatching.bundleID(fromFileName: "com.foo.Bar") == "com.foo.Bar", "no extension")

        print("System ids are protected:")
        ok(LeftoverMatching.isSystem("com.apple.Safari"), "com.apple.* is system")
        ok(LeftoverMatching.isSystem("group.com.apple.notes"), "group.com.apple.* is system")
        ok(!LeftoverMatching.isSystem("com.google.Chrome"), "third-party not system")

        print("Orphan detection (never matches installed or by name):")
        let installed: Set<String> = ["com.google.chrome", "com.tinyapp.tool"]
        ok(LeftoverMatching.isOrphan("com.oldvendor.GoneApp", installed: installed), "uninstalled bundle → orphan")
        ok(!LeftoverMatching.isOrphan("com.google.Chrome", installed: installed), "installed (case-insensitive) → not orphan")
        ok(!LeftoverMatching.isOrphan("com.apple.Safari", installed: installed), "apple id → never orphan")
        ok(!LeftoverMatching.isOrphan("Spotify", installed: installed), "plain name → never orphan (no substring match)")

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
