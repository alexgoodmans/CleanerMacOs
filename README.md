# Again Cleaner

Safe, no-nonsense disk cleanup for macOS. See exactly what takes space, choose what to remove, and clean with confidence — again and again.

**Website / Download:** [againcleaner.com](https://againcleaner.com) · Free · Signed & notarized by Apple · No subscriptions

![Platform](https://img.shields.io/badge/platform-macOS%2026.5+-blue) ![Swift](https://img.shields.io/badge/Swift-5-orange) ![License](https://img.shields.io/badge/price-free-brightgreen)

## Features

- **Junk scan** — 35+ curated categories plus three auto-generators:
  - every app's cache in `~/Library/Caches`
  - Electron/Chromium junk (`Cache`, `GPUCache`, logs…) of any app in `~/Library/Application Support`
  - **universal build artifacts** across your whole home folder — `node_modules`, `target` (Rust), `build` (Gradle/CMake), `__pycache__`/`.venv` (Python), `vendor` (PHP/Go), `bin`/`obj` (.NET) — validated by marker files (`Cargo.toml`, `package.json`, `composer.json`…) so nothing unrelated ever matches
- **Safety levels** — every category is tagged Safe / Caution / Risky; risky ones are never pre-selected
- **File-level control** — expand any category, tick exactly what goes; parent/child checkboxes cascade
- **Large file hunter** — find forgotten files over a configurable threshold, reveal in Finder or delete
- **Favorites** — pin folders you clean often, empty them all in one click
- **Trash by default** — everything is recoverable unless you explicitly choose permanent deletion
- **Localized** — English, Русский, ไทย

Developer-junk aware: Xcode DerivedData / DeviceSupport / simulators, iOS device backups, Homebrew, npm/Yarn/pnpm, pip, CocoaPods, Gradle, Go modules, NuGet, Conan and more.

## Build

```bash
open "Again Cleaner.xcodeproj"   # Xcode 26+, macOS 26.5+ SDK
```

Or from the command line:

```bash
xcodebuild -project "Again Cleaner.xcodeproj" -scheme "Again Cleaner" \
  -configuration Release -destination 'platform=macOS' build
```

App Sandbox is disabled (the cleaner needs real filesystem access), hardened runtime is on.

## Release

```bash
./scripts/release.sh      # archive → Developer ID export → notarize → staple → signed .dmg
./scripts/upload-dmg.sh   # push the .dmg to object storage (creds from env)
```

## Repository layout

```
Again Cleaner/        SwiftUI app (models, services, view models, views)
landing/              Vite + React + TS + Tailwind + shadcn/ui website
landing/deploy/       nginx templates (rate limiting, security headers, S3 redirect)
scripts/              release & upload automation
marketing/            launch article
```

## Safety principles

The app never decides for you: it finds, measures and *suggests*. Dangerous locations (Keychains, Mail, Messages, iCloud documents) are simply not part of the catalog, so they cannot be selected even by accident.

---

© 2026 Digkill · MediaRise · [Buy the dev a coffee ☕](https://www.donationalerts.com/r/digkill)
