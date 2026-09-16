#!/bin/bash
#
# run.sh — compile & run the safety/parsing unit tests against the REAL source
# files. These live outside the app target (so a test's top-level entry point
# never gets compiled into the app) but compile the actual production code.
#
#   ./tests/run.sh
#
set -euo pipefail
cd "$(dirname "$0")"

SRC="../Again Cleaner"
TMP="$(pwd)/.test-build"
rm -rf "$TMP"
mkdir -p "$TMP"
export TMPDIR="$TMP"
fails=0

echo "▶︎ PathGuard safety tests"
xcrun swiftc -swift-version 6 "$SRC/Safety/PathGuard.swift" PathGuardTests.swift -o "$TMP/pathguard"
"$TMP/pathguard" || fails=$((fails+1))

echo ""
echo "▶︎ Docker parsing tests"
xcrun swiftc -swift-version 6 "$SRC/Services/DockerParsing.swift" DockerParsingTests.swift -o "$TMP/docker"
"$TMP/docker" || fails=$((fails+1))

echo ""
echo "▶︎ Analyzer parsing tests (DeviceSupport, versions)"
xcrun swiftc -swift-version 6 \
    "$SRC/Services/DeviceSupportParsing.swift" \
    "$SRC/Services/VersionOrdering.swift" \
    AnalyzerParsingTests.swift -o "$TMP/analyzer"
"$TMP/analyzer" || fails=$((fails+1))

echo ""
echo "▶︎ Detector logic tests (extensions, artifacts, Android, AI, risk)"
xcrun swiftc -swift-version 6 \
    "$SRC/Services/VersionOrdering.swift" \
    "$SRC/Services/EditorExtensionParsing.swift" \
    "$SRC/Services/ProjectRootDetector.swift" \
    "$SRC/Services/AndroidSDKParsing.swift" \
    "$SRC/Services/AIModelDetection.swift" \
    "$SRC/Models/ScanCategory.swift" \
    "$SRC/Models/CleanupModels.swift" \
    "$SRC/Models/CleanupCandidate.swift" \
    "$SRC/Services/FileKind.swift" \
    "$SRC/Services/FileAttribution.swift" \
    -framework SwiftUI \
    DetectorLogicTests.swift -o "$TMP/detector"
"$TMP/detector" || fails=$((fails+1))

echo ""
echo "▶︎ Filesystem safety tests (artifacts, symlinks, parent paths)"
xcrun swiftc -swift-version 6 \
    "$SRC/Safety/PathGuard.swift" \
    "$SRC/Services/ProjectRootDetector.swift" \
    "$SRC/Services/EditorExtensionParsing.swift" \
    "$SRC/Services/VersionOrdering.swift" \
    "$SRC/Services/FileSystemEngine.swift" \
    "$SRC/Models/CleanupModels.swift" \
    "$SRC/Services/FileKind.swift" \
    "$SRC/Services/FileAttribution.swift" \
    FilesystemSafetyTests.swift -o "$TMP/fs"
"$TMP/fs" || fails=$((fails+1))

echo ""
echo "▶︎ Leftover matching tests"
xcrun swiftc -swift-version 6 "$SRC/Services/LeftoverMatching.swift" LeftoverMatchingTests.swift -o "$TMP/leftover"
"$TMP/leftover" || fails=$((fails+1))

echo ""
echo "▶︎ Chromium storage tests"
xcrun swiftc -swift-version 6 "$SRC/Services/ChromiumStorage.swift" ChromiumStorageTests.swift -o "$TMP/chromium"
"$TMP/chromium" || fails=$((fails+1))

echo ""
echo "▶︎ Large file kind/attribution tests"
xcrun swiftc -swift-version 6 \
    "$SRC/Services/FileKind.swift" "$SRC/Services/FileAttribution.swift" \
    LargeFileTests.swift -o "$TMP/largefile"
"$TMP/largefile" || fails=$((fails+1))

echo ""
if [ "$fails" -eq 0 ]; then echo "✅ All test suites passed"; else echo "❌ $fails suite(s) failed"; fi
exit "$fails"
