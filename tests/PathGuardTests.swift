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

    print("PARENT / CHILD:")
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    let cache = homeURL.appendingPathComponent("Library/Caches/com.test")
    let nested = cache.appendingPathComponent("blob")
    if PathGuard.isStrictChild(nested, of: cache) { pass += 1; print("  ✓ nested cache is child") }
    else { fail += 1; print("  ✗ FAIL nested cache is child") }
    if !PathGuard.isStrictChild(cache, of: nested) { pass += 1; print("  ✓ reverse child false") }
    else { fail += 1; print("  ✗ FAIL reverse child false") }

    print("MUST BE ALLOWED:")
    for p in ["~/Library/Caches/com.test.app","~/Library/Logs/SomeApp","~/.gradle/caches",
              "~/go/pkg/mod","~/Downloads/old.zip","~/Projects/app/node_modules",
              "/Library/Caches/SomeCache"] {
        check(PathGuard.verdict(for: u(p)), blocked: false, p)
    }

    print("REGRESSION: existing catalog targets must still be allowed:")
    for p in [
        "~/Music/iTunes/iTunes Media/Mobile Applications/App.ipa",  // iTunes mobile apps
        "~/Dropbox/.dropbox.cache/blob",                            // Dropbox cache
        "~/Library/Application Support/Steam/appcache",             // Steam
        "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads/x", // Mail Downloads
        "~/Library/Application Support/MobileSync/Backup/UDID",     // iOS backups
        "~/Library/Developer/CoreSimulator/Devices/ABC",            // simulators
        "~/Library/Developer/Xcode/DerivedData/App-xyz",           // DerivedData
        "~/.espressif/dist/tool.tar.gz", "~/.nuget/packages/pkg",   // dev caches
        "~/Library/Application Support/OptGuideOnDeviceModel/2025", // Xcode model
    ] {
        check(PathGuard.verdict(for: u(p)), blocked: false, p)
    }
    print("ROOT-ITSELF blocked:")
    check(PathGuard.verdict(for: u("~/Library/Caches")), blocked: true, "~/Library/Caches (root)")

    print("CREDENTIALS / KEYS — regression for the real incident (must ALWAYS be blocked, at any depth):")
    for p in [
        "~/.ssh/id_rsa", "~/.ssh/id_ed25519", "~/.ssh/config",
        "~/.gnupg/private-keys-v1.d/ABCDEF.key",
        "~/.aws/credentials", "~/.aws/config",
        "~/.kube/config", "~/.azure/accessTokens.json",
        "~/.docker/config.json",
        "~/.netrc", "~/.npmrc", "~/.git-credentials", "~/.pgpass",
        // The actual gap: Keychains was blocked as a folder, not its CONTENTS.
        "~/Library/Keychains/login.keychain-db",
        "~/Library/Keychains/ABCDEF-1234/keychain-2.db",
        // Even nested arbitrarily deep inside an otherwise-allowed cleanup root.
        "~/Library/Caches/SomeVendor/.aws/credentials",
        "~/.terraform.d/credentials.tfrc.json",
        // Key/cert file extensions anywhere.
        "~/Downloads/server.pem", "~/Downloads/release.keystore",
        "~/Desktop/backup.p12", "~/Projects/app/private.key",
    ] {
        check(PathGuard.verdict(for: u(p)), blocked: true, p)
    }

    print("\n\(pass) passed, \(fail) failed")
    return fail == 0 ? 0 : 1
}
}
