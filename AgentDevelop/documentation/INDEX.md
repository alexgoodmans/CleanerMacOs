---
title: Документация Again Cleaner
---

# Документация

Память агентов: [`docs/memory/README.md`](../../docs/memory/README.md). Продукт: [`README.md`](../../README.md).

## Два пайплайна

| Пайплайн | Вход | Удаление |
|---|---|---|
| Junk Cleanup | `CleanupCatalog` + `CleanRule` | `FileSystemEngine.remove` |
| Smart Scan | `CleanupScanner` → `ScanCoordinator` | `CleanupExecutor` |

Оба режутся об `PathGuard` + `CleanupSafetyPolicy`. Корзина по умолчанию.

## Сканеры

Новый источник мусора = новый `CleanupScanner`, регистрация в `ScanCoordinator.standard`. Универсальные build-папки только с маркер-файлами (`ProjectRootDetector`).

## Релиз

`scripts/release.sh` — archive → Developer ID → notarize → staple → DMG. Sandbox выключен, hardened runtime включён.
