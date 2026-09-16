# Architecture

## High-level layers

```
Views (SwiftUI)
    ↓
ViewModels (@MainActor ObservableObject)
    ↓
┌─────────────────────┬──────────────────────────┐
│ Legacy Junk path    │ Smart Scan path          │
│ CleanupCatalog      │ ScanCoordinator          │
│ FileSystemEngine    │ CleanupScanner[]         │
│ CleanRule           │ CleanupCandidate         │
└─────────┬───────────┴────────────┬─────────────┘
          ↓                        ↓
    PathGuard / CleanupSafetyPolicy (all deletes)
          ↓
    CleanupExecutor / FileSystemEngine.remove
```

Two pipelines coexist on purpose: **Junk Cleanup** keeps the working catalog UI; **Smart Scan** is the modular analyzer. Do not merge them casually.

## App entry

- `Again_CleanerApp` → `ContentView`
- `ContentView` owns three VMs: `CleanerViewModel`, `SmartScanModel`, `DeepDiskModel`
- Sidebar: `NavigationSplitView` + `Section` enum

## Pipeline A — Junk Cleanup (catalog)

1. `CleanupCatalog.all` → `[JunkCategory]` (curated + generated caches + Electron + user folders).
2. `CleanerViewModel` measures via `FileSystemEngine.resolve` / size APIs off main actor.
3. User selects categories / per-file ticks (`itemSelected`).
4. Clean via `FileSystemEngine.remove` (Trash or unlink), still subject to PathGuard inside engine paths used by VM.

`CleanRule` declares *how* a category resolves targets:

- `clearContents` — delete children, keep dir
- `removePaths` — delete listed paths
- `findDirs` — find named dirs under roots
- `scanArtifacts` — build artifacts with marker validation
- `oldItems` — stale items in Downloads/Desktop
- `largeChildren` — large top-level children (always Risky)

## Pipeline B — Smart Scan (scanners)

1. `ScanCoordinator.standard` lists all `CleanupScanner`s.
2. Filter `isAvailable()`, fan-out with `TaskGroup`, shared `ScanContext` (`DiskUsageService` + cancel).
3. Progress + partial results → main actor callbacks.
4. `dedupe`: drop `builtin:*` candidates under dedicated scanners’ `ownedPrefixes`; exact-path dedupe prefers non-builtin.
5. `SmartScanModel` filters `IgnoreStore`, auto-selects `CleanupSafetyPolicy.isSmartCleanEligible`.
6. Clean via `CleanupExecutor` (method dispatch + PathGuard). `RunningAppGuard` may block until apps quit.

## Pipeline C — Deep Disk

- `DeepDiskModel` + `DiskUsageService` (actor): volume-aware child sizes, breadcrumbs, quick roots (`Home`, `Library`, `/`, …).
- Exploration only (not the same as Smart Scan cleanup).

## Concurrency conventions

- Scanners / engine / PathGuard: `nonisolated` + `Sendable` where possible.
- UI state: `@MainActor` view models.
- Cancel: `CancelToken` (`OSAllocatedUnfairLock`) polled from background work.
- Prefer not to hop actors per file during scans.

## Release / build

```bash
open "Again Cleaner.xcodeproj"
xcodebuild -project "Again Cleaner.xcodeproj" -scheme "Again Cleaner" \
  -configuration Release -destination 'platform=macOS' build
./scripts/release.sh      # archive → export → notarize → staple → dmg
./scripts/upload-dmg.sh   # push dmg (creds from env)
```
