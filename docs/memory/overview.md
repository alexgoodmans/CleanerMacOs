# Product overview

**Again Cleaner** — free macOS disk cleaner: find reclaimable junk, show sizes, let the user choose, then clean (Trash by default). Site: [againcleaner.com](https://againcleaner.com). Author: Digkill / MediaRise.

## Stack

| Area | Tech |
|------|------|
| App | SwiftUI, Swift 6, macOS 26.5+ SDK, Xcode 26+ |
| Sandbox | **Disabled** (needs full FS); hardened runtime on |
| Release | Developer ID + notarize + staple → `.dmg` via `scripts/release.sh` |
| Landing | Vite + React 19 + TS + Tailwind 4 (`landing/`) |
| Locales | English, Русский, ไทย |

## Repo layout

```
Again Cleaner/          SwiftUI app sources
  Models/               JunkCategory, CleanupCandidate, catalog, ScanCategory
  Scanners/             CleanupScanner protocol + implementations + coordinator
  Services/             FS engine, executor, parsing helpers, ProcessRunner
  Safety/               PathGuard, CleanupSafetyPolicy
  ViewModels/           CleanerViewModel, SmartScanModel, DeepDiskModel
  Views/                Sidebar sections UI
Again Cleaner.xcodeproj
tests/                  Standalone swiftc suites (./tests/run.sh)
scripts/                release.sh, upload-dmg.sh
landing/                Product website
marketing/              Launch articles
docs/memory/            This agent memory
```

## Features (UI sections)

| Section | ViewModel | Role |
|---------|-----------|------|
| Overview | `CleanerViewModel` | Disk summary / entry |
| Smart Scan | `SmartScanModel` | Modular scanners → `CleanupCandidate` |
| Deep Disk Scan | `DeepDiskModel` | Browse size tree (`DiskUsageService`) |
| Junk Cleanup | `CleanerViewModel` | Catalog categories + `FileSystemEngine` |
| Large Files | `CleanerViewModel` | Threshold hunter |
| Favorites | `CleanerViewModel` | Pinned folders |
| Donate / About | — | Optional donate (`Donation.isEnabled`) |

## Safety product principles

- App **suggests**; user decides. Risky items never pre-selected.
- Dangerous locations (Keychains, Mail, Messages, iCloud docs) are **not in the catalog**.
- Default clean path: **move to Trash** (`moveToTrash = true`).
- Every filesystem delete is gated by `PathGuard` + `CleanupSafetyPolicy`.
