import Foundation

@main
enum AnalyzerParsingTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func ok(_ cond: Bool, _ label: String) {
            if cond { pass += 1; print("  ✓ \(label)") }
            else { fail += 1; print("  ✗ FAIL \(label)") }
        }

        print("DeviceSupport folder parsing:")
        let a = DeviceSupportParsing.parse("iPhone17,2 27.0 (24A5390f)")
        ok(a.device == "iPhone17,2" && a.version == "27.0" && a.build == "24A5390f", "device+version+build")
        let b = DeviceSupportParsing.parse("16.4 (20E247)")
        ok(b.device == nil && b.version == "16.4" && b.build == "20E247", "legacy version-only")

        print("Duplicate & old DeviceSupport detection:")
        let cls = DeviceSupportParsing.classify([
            "iPhone17,2 27.0 (24A5390f)",
            "iPhone17,2 27.0 (24A5408d)",
            "iPhone15,2 16.4 (20E247)",
        ])
        func find(_ raw: String) -> DeviceSupportParsing.Classified? { cls.first { $0.info.raw == raw } }
        ok(find("iPhone17,2 27.0 (24A5390f)")?.isDuplicate == true, "same device+version → duplicate")
        ok(find("iPhone17,2 27.0 (24A5390f)")?.isOld == true, "older build flagged old")
        ok(find("iPhone17,2 27.0 (24A5408d)")?.isOld == false, "newer build kept")
        ok(find("iPhone15,2 16.4 (20E247)")?.isDuplicate == false, "unique device → not duplicate")

        print("Version ordering / old SDK detection:")
        ok(VersionOrdering.compare("3.3.11", "3.3.2") == .orderedDescending, "3.3.11 > 3.3.2")
        ok(VersionOrdering.compare("3.2.0", "3.3.0") == .orderedAscending, "3.2.0 < 3.3.0")
        ok(VersionOrdering.newest(["3.2.0", "3.3.0", "3.3.11"]) == "3.3.11", "newest = 3.3.11")
        ok(VersionOrdering.olderThanNewest(["3.2.0", "3.3.0", "3.3.11"]) == ["3.2.0", "3.3.0"], "old set")
        ok(VersionOrdering.olderThanNewest(["4.0.0"]).isEmpty, "single version → nothing old")

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
