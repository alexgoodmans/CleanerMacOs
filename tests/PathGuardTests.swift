import Foundation

private func u(_ p: String) -> URL { URL(fileURLWithPath: (p as NSString).expandingTildeInPath) }

@main
enum PathGuardTests {
    static func main() { exit(run()) }

static func run() -> Int32 {
    var pass = 0, fail = 0
    func check(_ v: PathGuard.Verdict, blocked expected: Bool, _ label: String) {
        let isBlocked = !v.isAllowed
        if isBlocked == expected { pass += 1; print("  ✓ \(label)") }
        else { fail += 1; print("  ✗ FAIL \(label) — got \(v)") }
    }
    let home = FileManager.default.homeDirectoryForCurrentUser.path

    print("MUST BE BLOCKED:")
    for p in ["/","/System","/System/Volumes/Data","/Library","/usr","/private/var",
              "/private/var/db","/private/var/vm","/Users","/Applications"] {
        check(PathGuard.verdict(for: u(p)), blocked: true, p)
    }
    check(PathGuard.verdict(for: u(home)), blocked: true, "~ (home)")
    for p in ["~/Library","~/Documents","~/Library/Application Support","~/Library/Keychains"] {
        check(PathGuard.verdict(for: u(p)), blocked: true, p)
    }

    print("TRAVERSAL / SYMLINK:")
    check(PathGuard.verdict(for: u("~/Library/Caches/../../..")), blocked: true, "../ -> /Users")
    check(PathGuard.verdict(for: u("~/Library/Caches/../../../System")), blocked: true, "../ -> /System")
    let link = "/tmp/pg_link_\(getpid())"
    try? FileManager.default.removeItem(atPath: link)
    try? FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: "/System")
    check(PathGuard.verdict(for: URL(fileURLWithPath: link)), blocked: true, "symlink -> /System")
    try? FileManager.default.removeItem(atPath: link)
    check(PathGuard.verdict(for: u("/tmp/random")), blocked: true, "outside roots (/tmp)")

    print("MUST BE ALLOWED:")
    for p in ["~/Library/Caches/com.test.app","~/Library/Logs/SomeApp","~/.gradle/caches",
              "~/go/pkg/mod","~/Downloads/old.zip","~/Projects/app/node_modules",
              "/Library/Caches/SomeCache"] {
        check(PathGuard.verdict(for: u(p)), blocked: false, p)
    }
    print("ROOT-ITSELF blocked:")
    check(PathGuard.verdict(for: u("~/Library/Caches")), blocked: true, "~/Library/Caches (root)")

    print("\n\(pass) passed, \(fail) failed")
    return fail == 0 ? 0 : 1
}
}
