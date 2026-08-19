#!/bin/bash
#
# run.sh — compile & run the safety unit tests against the REAL source files.
#
# These live outside the app target (so the test's top-level `exit()` never
# gets compiled into the app) but compile the actual production Safety/*.swift,
# so they test the shipping code, not a copy.
#
#   ./tests/run.sh
#
set -euo pipefail
cd "$(dirname "$0")"

SRC="../Again Cleaner/Safety"
OUT="$(mktemp -d)/safety-tests"

xcrun swiftc -swift-version 6 \
    "$SRC/PathGuard.swift" \
    PathGuardTests.swift \
    -o "$OUT"

"$OUT"
