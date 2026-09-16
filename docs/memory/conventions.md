# Conventions for agents

## Do

- Prefer **additive** scanners over rewriting `CleanupCatalog` wholesale.
- Keep scanners **stateless** and `Sendable`; push pure logic into `Services/` for `swiftc` tests.
- Gate every delete path with `CleanupSafetyPolicy` / `PathGuard` — never bypass.
- Use **Trash** as the default UX (`moveToTrash`); permanent delete only when user opts in.
- Localize user-facing strings with `String(localized:)` / `LocalizedStringKey`.
- Match existing file headers and `nonisolated` style.
- After safety or artifact-matching changes, run `./tests/run.sh`.

## Don’t

- Don’t enable App Sandbox.
- Don’t auto-select `.risky` / `.reviewRequired` / `.dangerous` / `.neverDeleteAutomatically`.
- Don’t delete Keychains, Mail, Messages, iCloud documents, or protected PathGuard paths — keep them out of catalogs.
- Don’t follow directory symlinks when walking for junk.
- Don’t treat ambiguous `build`/`dist`/`vendor` as junk without markers.
- Don’t merge Smart Scan and Junk Cleanup VMs without an explicit redesign.
- Don’t commit secrets (`.env`, `.p8`, upload creds).
- Don’t expand scope into landing redesign / marketing unless asked.

## UI

- Sidebar sections live in `ContentView.Section`.
- Smart Scan UI: `SmartScanView` + `SmartScanModel`.
- Junk UI: `JunkView` + `CategoryItemsList` (cascading checkboxes).

## Naming

- Scanner files: `*Scanner.swift`
- Parsing helpers: `*Parsing.swift` or `*Detection.swift`
- Tests: mirror concern (`PathGuardTests.swift`, …)

## Dual Safety vs CleanupRisk

When bridging catalog → candidates, use `Safety.risk`. When inventing new Smart Scan items, pick `CleanupRisk` deliberately — regeneratable caches are usually `.usuallySafe`, user data review is `.reviewRequired`.
