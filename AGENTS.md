# Again Cleaner — agent brief

Портфолио и задачи агента: **[`AgentDevelop/`](AgentDevelop/README.md)** (синк в Composer).

Free macOS disk cleaner (SwiftUI). Dual pipelines: **Junk Cleanup** (`CleanupCatalog` + `FileSystemEngine`) and **Smart Scan** (`CleanupScanner` + `ScanCoordinator` + `CleanupExecutor`). Safety is non-negotiable: `PathGuard` + `CleanupSafetyPolicy` gate every delete; Trash by default.

## Before you code

1. Read [`docs/memory/README.md`](docs/memory/README.md) and the topic file that matches your task.
2. For scanners / cleanup / PathGuard: also read `protocols.md` + `safety.md`.
3. Run `./tests/run.sh` after safety or detector changes.

## Quick map

| Need | Look here |
|------|-----------|
| Add a junk source | New `CleanupScanner`, register in `ScanCoordinator.standard` |
| Catalog category only | `CleanupCatalog` + `CleanRule` |
| Deletion rules | `Safety/PathGuard.swift`, `CleanupSafetyPolicy.swift` |
| Execute clean | `CleanupExecutor` (methods) / `FileSystemEngine.remove` |
| UI section | `ContentView` → matching View + ViewModel |
| Tests | `tests/run.sh` |

## Hard constraints

- No App Sandbox.
- Never auto-delete dangerous / never-auto / review-required without user intent.
- Ambiguous build folders need marker files (`ProjectRootDetector`).
- Do not commit `.env` / signing secrets.
