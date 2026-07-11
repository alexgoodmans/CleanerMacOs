// Yandex.Metrika counter — loaded as part of the bundle so the strict CSP
// (script-src 'self' + mc.yandex.ru) holds without 'unsafe-inline'.

const COUNTER_ID = 110608130

declare global {
  interface Window {
    ym?: {
      (id: number, method: string, ...args: unknown[]): void
      a?: unknown[]
      l?: number
    }
  }
}

export function initMetrika(): void {
  // Don't pollute analytics while developing locally.
  if (import.meta.env.DEV) return

  const w = window
  if (!w.ym) {
    const ym = function (...args: unknown[]) {
      ;(ym.a = ym.a || []).push(args)
    } as NonNullable<Window["ym"]>
    ym.l = Date.now()
    w.ym = ym
  }

  const src = "https://mc.yandex.ru/metrika/tag.js?id=" + COUNTER_ID
  if (![...document.scripts].some((s) => s.src === src)) {
    const script = document.createElement("script")
    script.async = true
    script.src = src
    document.head.appendChild(script)
  }

  w.ym(COUNTER_ID, "init", {
    ssr: true,
    webvisor: true,
    clickmap: true,
    ecommerce: "dataLayer",
    referrer: document.referrer,
    url: location.href,
    accurateTrackBounce: true,
    trackLinks: true,
  })
}
