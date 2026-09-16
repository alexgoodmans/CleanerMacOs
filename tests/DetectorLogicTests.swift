import Foundation

@main
enum DetectorLogicTests {
    static func main() { exit(run()) }

    static func run() -> Int32 {
        var pass = 0, fail = 0
        func ok(_ cond: Bool, _ label: String) {
            if cond { pass += 1; print("  ✓ \(label)") }
            else { fail += 1; print("  ✗ FAIL \(label)") }
        }

        print("Editor extension parse / stale versions:")
        let p = EditorExtensionParsing.parse("openai.chatgpt-0.1.26-universal")
        ok(p?.extensionID == "openai.chatgpt" && p?.version == "0.1.26-universal", "chatgpt vsix name")
        ok(EditorExtensionParsing.parse("ms-python.python-2024.8.1")?.extensionID == "ms-python.python", "ms-python id")
        ok(EditorExtensionParsing.parse("not-an-extension") == nil, "reject unversioned")
        let groups = EditorExtensionParsing.groups(from: [
            "openai.chatgpt-0.1.20",
            "openai.chatgpt-0.1.26-universal",
            "openai.chatgpt-0.1.25",
            "dart-code.dart-3.120.0",
        ])
        let gpt = groups.first { $0.extensionID == "openai.chatgpt" }
        ok(gpt?.newest.version == "0.1.26-universal", "newest is 0.1.26 not lexical 0.1.9")
        ok(gpt?.stale.count == 2, "two stale chatgpt versions")
        ok(gpt?.installedCount == 3, "installed count")
        ok(VersionOrdering.compare("0.1.26", "0.1.9") == .orderedDescending, "semver 0.1.26 > 0.1.9")

        print("Project artifact recognition / false-positive build:")
        ok(ProjectRootDetector.isProjectRoot(contents: ["package.json", "src"]), "package.json root")
        ok(ProjectRootDetector.isProjectRoot(contents: ["App.xcodeproj", "README"]), "xcodeproj root")
        ok(!ProjectRootDetector.isProjectRoot(contents: ["Photos", "IMG_0001.heic"]), "photos folder is not a project")
        ok(ProjectRootDetector.isValidArtifact(name: "node_modules", parentContents: ["src"]), "node_modules unambiguous")
        ok(ProjectRootDetector.isValidArtifact(name: "target", parentContents: ["Cargo.toml", "src"]), "rust target")
        ok(!ProjectRootDetector.isValidArtifact(name: "target", parentContents: ["README.md"]), "target without Cargo.toml")
        ok(!ProjectRootDetector.isValidArtifact(name: "build", parentContents: ["index.html"]), "false-positive build folder")
        ok(ProjectRootDetector.isValidArtifact(name: "build", parentContents: ["app"], grandparentContents: ["build.gradle"]), "android app/build via grandparent")
        ok(ProjectRootDetector.isValidArtifact(name: ".cxx", parentContents: ["src"], grandparentContents: ["build.gradle.kts"]), "android .cxx")
        ok(ProjectRootDetector.isValidArtifact(name: "venv", parentContents: [], childContents: ["pyvenv.cfg"]), "venv with pyvenv.cfg")
        ok(!ProjectRootDetector.isValidArtifact(name: "venv", parentContents: [], childContents: ["data"]), "venv without pyvenv.cfg")
        ok(ProjectRootDetector.isValidArtifact(name: "dist", parentContents: ["package.json"]), "js dist")
        ok(!ProjectRootDetector.isValidArtifact(name: "dist", parentContents: ["Documents"]), "random dist")

        print("Android NDK / AVD / system image:")
        let img = AndroidSDKParsing.parseSystemImagePath("system-images/android-36/google_apis/arm64-v8a/")
        ok(img?.api == "36" && img?.flavor == "google_apis" && img?.abi == "arm64-v8a", "system image parse")
        let avd = AndroidSDKParsing.parseAVD(
            name: "Pixel_8",
            configINI: """
            AvdId=Pixel_8
            abi.type=arm64-v8a
            image.sysdir.1=system-images/android-36/google_apis_playstore/arm64-v8a/
            """
        )
        ok(avd.name == "Pixel_8" && avd.api == "36" && avd.imageRelativePath?.contains("playstore") == true, "AVD references playstore image")
        let ndkText = """
        android {
            ndkVersion "26.1.10909125"
        }
        ndk.dir=/opt/sdk/ndk/25.2.9519653
        """
        let refs = AndroidSDKParsing.ndkReferences(in: ndkText)
        ok(refs.contains("26.1.10909125"), "ndkVersion captured")
        ok(refs.contains("25.2.9519653"), "ndk.dir version captured")
        ok(AndroidSDKParsing.isReferenced(ndkVersion: "26.1.10909125", references: refs), "installed NDK referenced")
        ok(!AndroidSDKParsing.isReferenced(ndkVersion: "21.4.7075529", references: refs), "old NDK not referenced")
        ok(AndroidSDKParsing.sdkDir(fromLocalProperties: "sdk.dir=/Users/me/Library/Android/sdk\n") == "/Users/me/Library/Android/sdk", "local.properties sdk.dir")

        print("AI model classification:")
        ok(AIModelDetection.isModelFile(URL(fileURLWithPath: "/tmp/flux.safetensors")), "safetensors")
        ok(AIModelDetection.isModelFile(URL(fileURLWithPath: "/tmp/llama.gguf")), "gguf")
        ok(AIModelDetection.isModelDirectory(name: "Models", childNames: ["flux.safetensors"]), "Models dir")
        ok(AIModelDetection.isModelDirectory(name: "OptGuideOnDeviceModel", childNames: []), "on-device model folder")
        ok(!AIModelDetection.isModelDirectory(name: "Caches", childNames: ["data.bin"]), "caches is not a model")

        print("Risk grouping / reclaimable totals:")
        let safe = CleanupRisk.safe
        let review = CleanupRisk.reviewRequired
        ok(safe.isAutoSelectable && !review.isAutoSelectable, "review never auto-selected")
        ok(CleanupRisk.usuallySafe.isAutoSelectable, "usuallySafe auto")
        ok(!CleanupRisk.neverDeleteAutomatically.isDeletable, "never auto-delete not deletable")
        ok(!CleanupRisk.dangerous.isDeletable, "dangerous not deletable")

        print("\n\(pass) passed, \(fail) failed")
        return fail == 0 ? 0 : 1
    }
}
