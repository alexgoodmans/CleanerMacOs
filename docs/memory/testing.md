# Testing

Tests are **outside** the Xcode app target. `./tests/run.sh` compiles production sources + test files with `xcrun swiftc -swift-version 6` into `tests/.test-build/`.

```bash
./tests/run.sh
```

## Suites

| Suite | Production sources | Focus |
|-------|-------------------|--------|
| PathGuard | `Safety/PathGuard.swift` | allow/deny paths |
| Docker parsing | `Services/DockerParsing.swift` | CLI output parsing |
| Analyzer parsing | DeviceSupport + VersionOrdering | version / DeviceSupport |
| Detector logic | ProjectRoot, Android, AI, EditorExtension, models | markers, risk mapping |
| Filesystem safety | PathGuard + FileSystemEngine + ProjectRoot | artifacts, symlinks, parents |
| Leftover matching | `LeftoverMatching.swift` | orphan app data matching |
| Chromium storage | `ChromiumStorage.swift` | browser storage paths |
| Large files | FileKind + FileAttribution | kind/owner |

## Rules when adding tests

1. Keep tests filesystem-light / pure when possible (temp dirs ok).
2. Wire new sources into the matching `swiftc` invocation in `run.sh`.
3. Do not add a `@main` that would ship in the app — test entry points stay in `tests/`.
4. `tests/.test-build/` is gitignored.

## Manual app checks (when touching clean flows)

- Smart Scan: auto-select only safe/usuallySafe; PathGuard blocks protected paths.
- Junk: risky categories unchecked; expand → per-file ticks cascade.
- Running apps: Clean blocked until Quit when `RunningAppGuard` finds matches.
- Recovered bytes ≈ real free-space delta after Trash empty / purge settle.
