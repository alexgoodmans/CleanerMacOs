# Landing site

Path: `landing/` — marketing site for [againcleaner.com](https://againcleaner.com).

| Piece | Detail |
|-------|--------|
| Stack | Vite 7, React 19, TypeScript, Tailwind 4, shadcn-style components |
| i18n | `landing/src/i18n/translations.json` |
| Deploy | `landing/deploy/` — nginx templates (rate limit, security headers, S3 redirect) |
| Scripts | `npm run dev` / `build` / `preview` |

Agent note: treat landing as a **separate** product surface from the Swift app. Prefer not to mix app safety changes with landing CSS unless the task asks for both.

Marketing copy drafts: `marketing/devto-article.md`, `marketing/habr-article.md`.
