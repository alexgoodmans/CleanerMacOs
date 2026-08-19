import Foundation

@main
enum DockerParsingTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func eq<T: Equatable>(_ got: T, _ want: T, _ label: String) {
            if got == want { pass += 1; print("  ✓ \(label)") }
            else { fail += 1; print("  ✗ FAIL \(label) — got \(got), want \(want)") }
        }

        print("SIZE TOKEN PARSING:")
        eq(DockerParsing.bytes(from: "10.27GB"), 10_270_000_000, "10.27GB")
        eq(DockerParsing.bytes(from: "512MB"),   512_000_000,    "512MB")
        eq(DockerParsing.bytes(from: "0B"),      0,              "0B")
        eq(DockerParsing.bytes(from: "1.2kB"),   1_200,          "1.2kB")
        eq(DockerParsing.bytes(from: "3TB"),     3_000_000_000_000, "3TB")
        eq(DockerParsing.bytes(from: "N/A"),     0,              "N/A")
        eq(DockerParsing.bytes(from: ""),        0,              "empty")

        print("docker system df TABLE PARSING:")
        let sample = """
        TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
        Images          10        2         5.2GB     3.1GB (59%)
        Containers      3         1         1.2MB     0B (0%)
        Local Volumes   8         2         2.3GB     1.1GB (47%)
        Build Cache     120       0         10.27GB   10.27GB
        """
        let rows = DockerParsing.parseSystemDF(sample)
        eq(rows.count, 4, "row count")
        if let bc = rows.first(where: { $0.type == "Build Cache" }) {
            eq(bc.reclaimable, 10_270_000_000, "Build Cache reclaimable = 10.27GB")
            eq(bc.total, 120, "Build Cache total = 120")
        } else { fail += 1; print("  ✗ FAIL no Build Cache row") }
        if let vol = rows.first(where: { $0.type == "Local Volumes" }) {
            eq(vol.reclaimable, 1_100_000_000, "Local Volumes reclaimable = 1.1GB")
            eq(vol.size, 2_300_000_000, "Local Volumes size = 2.3GB")
        } else { fail += 1; print("  ✗ FAIL no Local Volumes row") }
        if let img = rows.first(where: { $0.type == "Images" }) {
            eq(img.active, 2, "Images active = 2")
        } else { fail += 1; print("  ✗ FAIL no Images row") }

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
