import Foundation

@main
enum LargeFileTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func eq<T: Equatable>(_ got: T, _ want: T, _ label: String) {
            if got == want { pass += 1; print("  ✓ \(label)") }
            else { fail += 1; print("  ✗ FAIL \(label) — got \(got), want \(want)") }
        }
        func u(_ p: String) -> URL { URL(fileURLWithPath: p) }

        print("FileKind by extension:")
        eq(FileKind.of(u("/x/disk.iso")), .diskImage, "iso")
        eq(FileKind.of(u("/x/App.dmg")), .diskImage, "dmg")
        eq(FileKind.of(u("/x/vm.qcow2")), .vm, "qcow2")
        eq(FileKind.of(u("/x/box.vmdk")), .vm, "vmdk")
        eq(FileKind.of(u("/x/archive.tar.gz")), .archive, "tar.gz")
        eq(FileKind.of(u("/x/clip.MOV")), .video, "MOV case-insensitive")
        eq(FileKind.of(u("/x/setup.pkg")), .installer, "pkg")
        eq(FileKind.of(u("/x/notes.txt")), .other, "txt → other")

        print("FileAttribution owner from path:")
        eq(FileAttribution.owner(for: u("/Users/me/VMs/ubuntu.qcow2")), "Virtual Machine", "vm file")
        eq(FileAttribution.owner(for: u("/Users/me/Library/Developer/CoreSimulator/Devices/X/data/big")),
           "iOS Simulator", "CoreSimulator")
        eq(FileAttribution.owner(for: u("/Users/me/Library/Developer/Xcode/DerivedData/MyApp-abc123/Build/x.o")),
           "MyApp", "DerivedData → project")
        eq(FileAttribution.owner(for: u("/Users/me/proj/frontend/node_modules/pkg/big.bin")),
           "frontend", "node_modules → parent project")
        eq(FileAttribution.owner(for: u("/Users/me/Library/Containers/com.foo.Bar/Data/big")),
           "com.foo.Bar", "container id")
        eq(FileAttribution.owner(for: u("/Users/me/Movies/holiday.mp4")), nil, "unknown → nil")

        eq(FileAttribution.project(fromDerivedData: "MyApp-abc123"), "MyApp", "strip build hash")

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
