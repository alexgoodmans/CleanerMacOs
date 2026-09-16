# Safety model

Deletion is a hard requirement: **nothing is unlinked without gates**. When changing scanners or executor, re-read this file.

## Two risk scales

### Catalog UI — `Safety` (3 levels)

| Level | Meaning | Default selection |
|-------|---------|-------------------|
| `.safe` | caches, logs, trash | may pre-select |
| `.caution` | regeneratable (DerivedData, PM caches) | careful |
| `.risky` | simulators, heavy app data | **never** pre-selected |

Mapped to Smart Scan: `safe`→`.safe`, `caution`→`.usuallySafe`, `risky`→`.reviewRequired`.

### Smart Scan — `CleanupRisk` (5 levels)

| Level | Auto-select | Deletable in UI |
|-------|-------------|-----------------|
| `.safe` | yes | yes |
| `.usuallySafe` | yes | yes |
| `.reviewRequired` | no | yes (user ticks) |
| `.dangerous` | no | **no** (policy blocks) |
| `.neverDeleteAutomatically` | no | **no** (size display only) |

`isAutoSelectable` = safe | usuallySafe.  
`isDeletable` = not dangerous and not neverDeleteAutomatically.

## PathGuard (`Safety/PathGuard.swift`)

Last line of defence before filesystem delete:

1. Canonicalize (symlinks + `..`).
2. Block protected system / home sensitive paths (and ancestors of protected paths).
3. Allow only paths **strictly under** `allowedRoots` (never equal to a root itself).
4. Home itself is an allowed root so build artifacts under `~/…` can be cleaned; sensitive top-level folders (`~/Library`, Keychains, Mail, …) stay protected as wholes.

Verdict: `.allowed` | `.blocked(String)`.

## CleanupSafetyPolicy

Combines risk + PathGuard. Executor always calls `verdict(for:)` before acting; re-checks PathGuard immediately before unlink (TOCTOU / symlink retarget).

## Extra executor guards

- Refuse deleting a path whose directory listing looks like a **project root** (`ProjectRootDetector.isProjectRoot`).
- Skip child if a selected ancestor path already covers it.
- Measure real free-space delta (`DiskSpace`) after settle delay — UI shows actual recovery, not sum of sizes.

## Artifact / project safety

Ambiguous names (`build`, `target`, `dist`, `vendor`, …) only match when marker files prove ecosystem (`ProjectRootDetector.artifactMarkers` / `FileSystemEngine.artifactMarkers`). Unambiguous names (`node_modules`, `__pycache__`, …) match without markers.

## Symlinks

- Size walks / listings skip following directory symlinks where helpers do so (`DirListing`, engine enumerator).
- PathGuard canonicalization defeats symlink escape to protected trees.

## Tests to run after safety changes

```bash
./tests/run.sh
```

Especially: `PathGuardTests`, `FilesystemSafetyTests`, `DetectorLogicTests`.
