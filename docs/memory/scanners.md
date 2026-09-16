# Scanner registry

Registered in `ScanCoordinator.standard` (order = registration order; execution is parallel).

| Scanner | Typical `id` | Owns prefixes? | Notes |
|---------|--------------|----------------|-------|
| `BuiltinCatalogScanner` | `builtin-catalog` / `builtin:*` | no | Bridge from `CleanupCatalog` |
| `CacheScanner` | cache* | yes (`~/Library/Caches`) | Per-app caches |
| `LogScanner` | log* | yes (logs root) | User logs |
| `DeveloperJunkScanner` | `devjunk` | — | Home-wide artifacts via markers |
| `XcodeScanner` | `xcode` | yes | DerivedData, simulators, etc. |
| `DeviceSupportScanner` | `device-support` | yes | iOS DeviceSupport |
| `GradleScanner` | `gradle` | yes (`~/.gradle`) | |
| `AndroidScanner` | `android`… | yes | SDK, AVDs, NDK |
| `CursorScanner` | cursor* | yes | Cursor storage |
| `EditorExtensionScanner` | `editor-ext`… | yes | VS Code / Cursor extensions caches |
| `ArduinoScanner` | `arduino` | yes | Embedded SDK |
| `ApplicationScanner` | `app:` | — | Large apps in `/Applications` |
| `ContainerScanner` | container / appsupport | yes | App Support / Containers breakdown |
| `AIModelScanner` | `aimodel`… | — | Local LLM weights |
| `SystemCacheScanner` | `syscache` | yes | System caches (careful risk) |
| `PythonScanner` | `python` | — | pip / venv caches |
| `DownloadsScanner` | `download` | yes | Large / stale downloads |
| `LargeDirectoryScanner` | `large-dir` | — | Oversized dirs |
| `APFSSnapshotScanner` | `apfs` | — | Local snapshots; method `.tmutil` |
| `BrowserScanner` | `browser` | yes | Chromium site data |
| `LeftoverScanner` | `leftover` | — | Orphan app support after uninstall |
| `DockerScanner` | `docker` | — | Prune methods via Docker CLI |
| `HomebrewScanner` | `homebrew` | — | `.homebrewCleanup` / cache |

## Adding a scanner checklist

1. New file under `Again Cleaner/Scanners/`.
2. Pure parsing helpers → `Services/` + test in `tests/`.
3. Append to `ScanCoordinator.standard`.
4. Set `ownedPrefixes` if overlapping catalog/builtin.
5. Infer or set `ScanCategory`; pick correct `CleanupRisk` / `CleanupMethod`.
6. Update this table.

## Category inference

`ScanCategory.infer(scannerID:)` maps id prefixes (`xcode`, `docker`, `gradle`, …) when scanners omit an explicit category. Prefer explicit `category:` in `CleanupCandidate` init for clarity.
