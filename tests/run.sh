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
TMP="$(mktemp -d)"
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
echo "▶︎ Leftover matching tests"
xcrun swiftc -swift-version 6 "$SRC/Services/LeftoverMatching.swift" LeftoverMatchingTests.swift -o "$TMP/leftover"
"$TMP/leftover" || fails=$((fails+1))

echo ""
echo "▶︎ Chromium storage tests"
xcrun swiftc -swift-version 6 "$SRC/Services/ChromiumStorage.swift" ChromiumStorageTests.swift -o "$TMP/chromium"
"$TMP/chromium" || fails=$((fails+1))

echo ""
if [ "$fails" -eq 0 ]; then echo "✅ All test suites passed"; else echo "❌ $fails suite(s) failed"; fi
exit "$fails"
