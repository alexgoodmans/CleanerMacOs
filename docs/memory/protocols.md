# Protocols & contracts

## `CleanupScanner` (primary protocol)

Defined in `Again Cleaner/Scanners/CleanupScanner.swift`.

```swift
nonisolated protocol CleanupScanner: Sendable {
    var id: String { get }              // stable, e.g. "xcode", "docker"
    var displayName: String { get }
    func isAvailable() -> Bool          // default: true
    var ownedPrefixes: [URL] { get }    // default: []
    func scan(_ ctx: ScanContext) async -> [CleanupCandidate]
}

nonisolated struct ScanContext: Sendable {
    let usage: DiskUsageService
    let isCancelled: @Sendable () -> Bool
}
```

### Rules for new scanners

1. Implement as `nonisolated struct …: CleanupScanner`.
2. Register in `ScanCoordinator.standard` scanners array.
3. Set `ownedPrefixes` if you replace coarse `BuiltinCatalogScanner` coverage (same subtrees).
4. Honour `ctx.isCancelled` during long walks.
5. Produce honest `CleanupRisk`, `CleanupMethod`, `explanation` / `consequence` / `recoveryDescription`.
6. Prefer `ScanContext` helpers in `ScannerSupport` (`DirListing`, candidate factories).
7. Keep parsing/pure logic in `Services/*Parsing.swift` for unit tests without FS.

### Ownership / dedupe

- Dedicated scanners own prefixes → coordinator drops `scannerID.hasPrefix("builtin:")` candidates under those paths.
- Exact path collision: dedicated wins over builtin.

## Cleanup method contract

`CleanupMethod` on `CleanupCandidate` — executor switches on it:

| Method | Action |
|--------|--------|
| `.filesystem` | PathGuard → refuse project roots → Trash/unlink via `FileSystemEngine` |
| `.dockerBuilderPrune` | `docker builder prune -f` |
| `.dockerImagePrune` | `docker image prune -f` |
| `.dockerVolumeRemove` | `docker volume rm <name>` |
| `.homebrewCleanup` | `brew cleanup` |
| `.tmutil` | `tmutil thinlocalsnapshots …` |
| `.manualOnly` | Never delete; Reveal in Finder |

Non-filesystem methods skip PathGuard path checks (tool owns safety); risk still gates via `CleanupSafetyPolicy`.

## Safety policy contract

`CleanupSafetyPolicy.verdict(for:)`:

- `.neverDeleteAutomatically` / `.dangerous` → blocked
- `.filesystem` → `PathGuard.verdict`
- other methods → allowed if risk ok

`isSmartCleanEligible` = auto-selectable risk **and** verdict allowed.

## Catalog bridge

`BuiltinCatalogScanner` wraps `CleanupCatalog` / `JunkCategory` into `CleanupCandidate`s (`scannerID` like `builtin:…`). Dedicated scanners gradually supersede overlapping catalog entries via ownership.

## Related non-protocol surfaces

| Type | Role |
|------|------|
| `DiskUsageService` | Actor for sized directory children |
| `ProcessRunner` | Timed CLI invocation |
| `IgnoreStore` | UserDefaults ignored cleanup paths |
| `RunningAppGuard` | Quit-before-clean for live apps |
| `ProjectRootDetector` | Marker-based project / artifact rules |
