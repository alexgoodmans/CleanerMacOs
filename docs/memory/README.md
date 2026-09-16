# Again Cleaner — agent memory

Persistent project context for AI agents. Read this folder before changing scanners, safety, cleanup, or UI flows.

| File | When to read |
|------|----------------|
| [overview.md](overview.md) | Product purpose, stack, repo layout |
| [architecture.md](architecture.md) | Layers, dual scan pipelines, data flow |
| [protocols.md](protocols.md) | `CleanupScanner`, contracts, cleanup methods |
| [safety.md](safety.md) | PathGuard, risk model, deletion gates |
| [scanners.md](scanners.md) | Registry of scanners + ownership |
| [data-models.md](data-models.md) | Core types (`CleanupCandidate`, `CleanRule`, …) |
| [conventions.md](conventions.md) | Coding rules agents must follow |
| [testing.md](testing.md) | How tests are built and run |
| [landing.md](landing.md) | Marketing site (`landing/`) |

Root entry points:

- [`AGENTS.md`](../../AGENTS.md) — short agent brief
- [`.cursor/rules/project-memory.mdc`](../../.cursor/rules/project-memory.mdc) — always-on Cursor rule
