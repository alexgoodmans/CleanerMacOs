# Data models

## Smart Scan path

| Type | File | Role |
|------|------|------|
| `CleanupCandidate` | `Models/CleanupCandidate.swift` | One reclaimable unit from a scanner |
| `CleanupRisk` | same | 5-level risk |
| `CleanupMethod` | same | How executor cleans |
| `ScanCategory` | `Models/ScanCategory.swift` | UI grouping |
| `ScanConfidence` | same | Classification confidence |
| `ScanAccessState` | same | scanned / inaccessible / permission / failed / cancelled |
| `CleanupReport` | `Services/CleanupExecutor.swift` | After-clean metrics |

### Important `CleanupCandidate` fields

- `scannerID`, `name`, `path`, `size`, `reclaimableBytes`
- `risk`, `category`, `subcategory`, `developer`
- `confidence`, `isRegenerable`, `requiresAdmin`
- `explanation`, `consequence`, `recoveryDescription`
- `method`, `accessState`
- `canUserDelete` / `contributesToTotals` — derived

Inaccessible paths must use `accessState != .scanned` — never report size 0 as “empty”.

## Junk Cleanup path

| Type | File | Role |
|------|------|------|
| `JunkCategory` | `Models/CleanupModels.swift` | Declarative category |
| `CleanRule` | same | How targets are resolved |
| `Safety` | same | 3-level risk for catalog UI |
| `CategoryScanResult` | same | Measured size / count |
| `TargetItem` | same | Expandable row file |
| `FavoriteFolder` | same | Pinned folder |
| `LargeFile` | same | Large-file hunter hit |
| `DiskInfo` | same | Boot volume snapshot |
| `CleanupCatalog` | `Models/CleanupCatalog.swift` | Built-in category list |

## Deep Disk

| Type | Role |
|------|------|
| `DiskChild` | Sized child entry |
| `DiskSpace.Snapshot` | Total / available |

## Shared helpers

| Type | Role |
|------|------|
| `FileKind` | Extension → kind for large files |
| `FileAttribution` | Best-effort owner app name |
| `Format` | Size / UI formatting |
