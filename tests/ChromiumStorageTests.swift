import Foundation

@main
enum ChromiumStorageTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func eq(_ got: String?, _ want: String?, _ label: String) {
            if got == want { pass += 1; print("  ✓ \(label)") }
            else { fail += 1; print("  ✗ FAIL \(label) — got \(got ?? "nil"), want \(want ?? "nil")") }
        }

        print("IndexedDB origin parsing:")
        eq(ChromiumStorage.origin(fromIndexedDBFolder: "https_studio.tripo3d.ai_0.indexeddb.leveldb"),
           "studio.tripo3d.ai", "https host")
        eq(ChromiumStorage.origin(fromIndexedDBFolder: "https_www.reddit.com_0.indexeddb.blob"),
           "www.reddit.com", ".blob variant")
        eq(ChromiumStorage.origin(fromIndexedDBFolder: "http_localhost_0.indexeddb.leveldb"),
           "localhost", "http localhost")
        eq(ChromiumStorage.origin(fromIndexedDBFolder: "chrome-extension_abcdef_0.indexeddb.leveldb"),
           nil, "extension origin rejected")
        eq(ChromiumStorage.origin(fromIndexedDBFolder: "file__0.indexeddb.leveldb"),
           nil, "file origin rejected")
        eq(ChromiumStorage.origin(fromIndexedDBFolder: "random-folder"),
           nil, "non-indexeddb rejected")

        print("Subdir classification is disjoint:")
        let cacheSet = Set(ChromiumStorage.cacheSubdirs)
        let storageSet = Set(ChromiumStorage.storageSubdirs)
        if cacheSet.isDisjoint(with: storageSet) { pass += 1; print("  ✓ cache vs storage disjoint") }
        else { fail += 1; print("  ✗ FAIL overlap between cache and storage") }

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
