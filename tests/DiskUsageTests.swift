import Foundation

/// Size calculation used by Deep Disk Scan and every scanner.
@main
enum DiskUsageTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func check(_ ok: Bool, _ label: String) {
            if ok { pass += 1; print("  ✓ \(label)") } else { fail += 1; print("  ✗ FAIL \(label)") }
        }

        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("diskusage-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        func write(_ rel: String, bytes: Int) -> URL {
            let url = root.appendingPathComponent(rel)
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            fm.createFile(atPath: url.path, contents: Data(repeating: 7, count: bytes))
            return url
        }
        func blocks(_ url: URL) -> Int64 {
            var st = stat()
            return lstat(url.path, &st) == 0 ? Int64(st.st_blocks) * 512 : 0
        }

        let a = write("a.bin", bytes: 100_000)
        let b = write("sub/b.bin", bytes: 50_000)
        let c = write("excluded/c.bin", bytes: 1_000_000)
        _ = write(".hidden/d.bin", bytes: 20_000)
        try? fm.linkItem(at: a, to: root.appendingPathComponent("sub/a-hardlink.bin"))
        try? fm.createSymbolicLink(at: root.appendingPathComponent("link-to-usr"),
                                   withDestinationURL: URL(fileURLWithPath: "/usr/share"))
        _ = write(".DS_Store", bytes: 6_000)

        let hidden = blocks(root.appendingPathComponent(".hidden/d.bin"))
        let dsStore = blocks(root.appendingPathComponent(".DS_Store"))
        let base = blocks(a) + blocks(b) + hidden + dsStore

        print("Measuring:")
        let all = DiskUsageService.measure(root)
        check(all == base + blocks(c), "allocated size = sum of st_blocks (\(all) == \(base + blocks(c)))")
        check(all > 0 && all < 10_000_000, "symlink to /usr/share is not followed")

        let withoutExcluded = DiskUsageService.measure(root, excluding: [root.appendingPathComponent("excluded").path])
        check(withoutExcluded == base, "excluded subtree is skipped")

        check(DiskUsageService.measure(a) == blocks(a), "a single file measures as itself")
        check(DiskUsageService.measure(root.appendingPathComponent("missing")) == 0, "missing path measures 0")

        print("Hard links:")
        let sub = DiskUsageService.measure(root.appendingPathComponent("sub"))
        check(sub == blocks(b) + blocks(a), "hard-linked file counted once within a walk")

        print("Listing:")
        let names = Set(DiskUsageService.listing(of: root).map(\.url.lastPathComponent))
        check(names.contains(".hidden"), "hidden folders are listed (like ~/Library, ~/.gradle)")
        check(!names.contains("link-to-usr"), "symlinks are not listed")
        check(!names.contains(".DS_Store"), ".DS_Store is not listed")
        check(names.isSuperset(of: ["a.bin", "sub", "excluded"]), "regular entries are listed")

        print("Volume root:")
        let rootNames = Set(DiskUsageService.listing(of: URL(fileURLWithPath: "/")).map(\.url.lastPathComponent))
        check(!rootNames.contains("Volumes") && !rootNames.contains("dev"), "/ listing leaves out /Volumes and /dev")
        check(rootNames.contains("Users") && rootNames.contains("System"), "/ listing keeps the firmlinked top-level folders")
        check(DiskUsageService.volumeRootExclusions.contains("/System/Volumes"),
              "/System/Volumes is excluded so the Data volume isn't counted twice")

        print("APFS service volumes:")
        check(DiskUsageService.volumeUsage(mountedAt: fm.homeDirectoryForCurrentUser.path) == nil,
              "a non-mount-point path has no volume usage (no parent-volume fallback)")
        if let data = DiskUsageService.volumeUsage(mountedAt: "/System/Volumes/Data"),
           let preboot = DiskUsageService.volumeUsage(mountedAt: "/System/Volumes/Preboot") {
            check(data != preboot && preboot < data,
                  "usage is per volume, not the container total (Data \(data / 1_000_000_000) GB vs Preboot \(preboot / 1_000_000_000) GB)")
        } else {
            check(false, "Data and Preboot volumes report their usage")
        }

        print("Cloud storage:")
        let home = fm.homeDirectoryForCurrentUser
        check(DiskUsageService.isCloudStorage(home.appendingPathComponent("Library/CloudStorage/OneDrive-Personal")),
              "File Provider folders are cloud storage")
        check(DiskUsageService.isCloudStorage(home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")),
              "iCloud Drive is cloud storage")
        check(!DiskUsageService.isCloudStorage(home.appendingPathComponent("Library/Caches")),
              "ordinary Library folders are not cloud storage")
        check(DiskUsageService.measure(home.appendingPathComponent("Library/CloudStorage")) == 0,
              "cloud roots are never walked (measure returns 0 immediately)")

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
