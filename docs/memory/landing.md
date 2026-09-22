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

## Screenshots and publishing

- Real macOS window captures live in `landing/public/screenshots/` (Overview, Junk Cleanup, Smart Scan). They were captured from the current running app, not generated or mocked. Do not invent disk or scan values.
- `AppScreenshot` is shared by the hero and the screenshot gallery. Each image opens at full resolution; gallery text is translated into all five site languages.
- The landing and README have no donation links. In the app, `Donation.isEnabled` is false and About has no donation link.
- Coolify application `againcleaner-landing` deploys GitLab `mediarise/again-cleaner`, branch `main`, Dockerfile build context `/landing`. Do not store deployment credentials in the repository.
- Verify with `cd landing && npm ci && npm run build`, then check all languages, gallery controls, download links, and 320–1440 px layouts.
