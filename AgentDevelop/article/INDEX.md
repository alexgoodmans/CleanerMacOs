---
title: Как делали Again Cleaner
---

# Статья: Again Cleaner

Чистильщик Mac обычно врёт размерами и подсовывает подписку. Здесь ставка на **каталог + политику**: приложение предлагает, человек ставит галочки.

## Безопасность как продукт

`PathGuard` каноникализирует путь, режет системные и чувствительные домашние каталоги, запрещает удалять сам корень (`allowedRoots` — только строго внутри). Рискованные категории не предвыбираются.

## Пример: уровни риска

```text
Catalog Safety: safe | caution | risky
Smart Scan:     safe | usuallySafe | reviewRequired | dangerous | neverDeleteAutomatically
```

`dangerous` и `neverDeleteAutomatically` нельзя отметить в UI.

## Маркетинг

Лендинг — Vite + React + Tailwind. Локали три: EN, RU, TH. Бесплатно — это позиция, не «временно».
