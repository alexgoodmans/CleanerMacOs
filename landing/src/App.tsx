import { useState } from "react"

import {
  BarChart3,
  Download,
  Search,
  Shield,
  Star,
  Trash2,
  Zap,
} from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { LANGS, LANG_NAMES, useI18n, type Lang } from "@/i18n"

export default function App() {
  return (
    <>
      <div className="bg-glow" aria-hidden />
      <div className="bg-grid" aria-hidden />
      <Header />
      <main>
        <Hero />
        <Stats />
        <Screenshots />
        <Steps />
        <Features />
        <SafetyLevels />
        <DownloadSection />
      </main>
      <Footer />
    </>
  )
}

function Container({ className = "", children }: { className?: string; children: React.ReactNode }) {
  return <div className={`mx-auto w-full max-w-6xl px-6 ${className}`}>{children}</div>
}

// ── Header ────────────────────────────────────────────────────────────────

function Header() {
  const { lang, setLang, t } = useI18n()
  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-background/70 backdrop-blur-xl">
      <Container className="flex min-h-16 flex-wrap items-center justify-between gap-3 py-3">
        <div className="flex items-center gap-3">
          <a href="#" className="flex items-center gap-3 font-bold">
            <img src="/icon.png" alt="" width={36} height={36} className="rounded-lg" />
            <span>Again Cleaner</span>
          </a>
          <DeveloperCredit className="border-l border-border/60 pl-3 text-xs" />
        </div>
        <div className="flex items-center gap-3">
          <select
            value={lang}
            onChange={(e) => setLang(e.target.value as Lang)}
            aria-label="Language"
            className="h-8 rounded-md border border-input bg-secondary px-2 text-xs text-foreground"
          >
            {LANGS.map((l) => (
              <option key={l} value={l}>
                {LANG_NAMES[l]}
              </option>
            ))}
          </select>
          <Button size="sm" asChild>
            <a href="#download">{t("nav.download")}</a>
          </Button>
        </div>
      </Container>
    </header>
  )
}

// ── Hero ──────────────────────────────────────────────────────────────────

function Hero() {
  const { t } = useI18n()
  return (
    <section className="py-16 md:py-24">
      <Container className="grid items-center gap-12 lg:grid-cols-[0.85fr_1.15fr]">
        <div>
          <Badge className="mb-6">{t("hero.badge")}</Badge>
          <h1 className="text-4xl font-extrabold leading-tight tracking-tight md:text-6xl">
            {t("hero.title1")}
            <br />
            <span className="bg-gradient-to-r from-emerald-300 to-teal-400 bg-clip-text text-transparent">
              {t("hero.title2")}
            </span>
          </h1>
          <p className="mt-6 max-w-lg text-lg text-muted-foreground">{t("hero.subtitle")}</p>
          <div className="mt-8 flex flex-wrap items-center gap-4">
            <Button size="lg" asChild>
              <a href="#download">
                <Download />
                {t("hero.cta")}
              </a>
            </Button>
            <span className="text-sm text-muted-foreground">{t("hero.meta")}</span>
          </div>
        </div>
        <AppScreenshot screen="overview" priority />
      </Container>
    </section>
  )
}

const screens = ["overview", "junk", "smart"] as const
type Screen = (typeof screens)[number]

function AppScreenshot({ screen, priority = false }: { screen: Screen; priority?: boolean }) {
  const { t } = useI18n()
  return (
    <a
      href={`/screenshots/${screen}.png`}
      target="_blank"
      rel="noopener noreferrer"
      aria-label={`${t(`screens.${screen}.title`)} — ${t("screens.enlarge")}`}
      className="block overflow-hidden rounded-xl border border-white/10 bg-card shadow-2xl shadow-black/30 transition-colors hover:border-primary/50 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
    >
      <img
        src={`/screenshots/${screen}.png`}
        alt={t(`screens.${screen}.alt`)}
        width={2360}
        height={1560}
        loading={priority ? "eager" : "lazy"}
        fetchPriority={priority ? "high" : "auto"}
        className="h-auto w-full"
      />
    </a>
  )
}

function Screenshots() {
  const { t } = useI18n()
  const [screen, setScreen] = useState<Screen>("junk")
  return (
    <section id="screenshots" className="py-20">
      <Container>
        <SectionHeader title={t("screens.title")} subtitle={t("screens.subtitle")} />
        <div className="mb-6 flex flex-wrap justify-center gap-2" role="group" aria-label={t("screens.title")}>
          {screens.map((item) => (
            <Button key={item} variant={screen === item ? "default" : "outline"} aria-pressed={screen === item} onClick={() => setScreen(item)}>
              {t(`screens.${item}.title`)}
            </Button>
          ))}
        </div>
        <div className="mx-auto max-w-5xl" aria-live="polite">
          <AppScreenshot screen={screen} />
          <p className="mt-5 text-center text-sm text-muted-foreground">{t(`screens.${screen}.desc`)}</p>
        </div>
        <p className="mt-2 text-center text-xs text-muted-foreground">{t("screens.enlarge")}</p>
      </Container>
    </section>
  )
}

// ── Stats ─────────────────────────────────────────────────────────────────

function Stats() {
  const { t } = useI18n()
  const stats = [
    { value: "30+", key: "stats.categories" },
    { value: "3", key: "stats.levels" },
    { value: "$0", key: "stats.price" },
    { value: "✓", key: "stats.notarized" },
  ]
  return (
    <section className="border-y border-border/60 bg-card/40 py-10">
      <Container className="grid grid-cols-2 gap-8 md:grid-cols-4">
        {stats.map(({ value, key }) => (
          <div key={key} className="text-center">
            <div className="bg-gradient-to-r from-emerald-300 to-teal-400 bg-clip-text text-3xl font-extrabold text-transparent">
              {value}
            </div>
            <div className="mt-1 text-sm text-muted-foreground">{t(key)}</div>
          </div>
        ))}
      </Container>
    </section>
  )
}

// ── Steps ─────────────────────────────────────────────────────────────────

function SectionHeader({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div className="mb-12 text-center">
      <h2 className="text-3xl font-bold tracking-tight md:text-4xl">{title}</h2>
      <p className="mt-3 text-muted-foreground">{subtitle}</p>
    </div>
  )
}

function Steps() {
  const { t } = useI18n()
  const steps = ["scan", "review", "clean"]
  return (
    <section className="py-20">
      <Container>
        <SectionHeader title={t("steps.title")} subtitle={t("steps.subtitle")} />
        <div className="grid gap-6 md:grid-cols-3">
          {steps.map((step, i) => (
            <Card key={step} className="relative overflow-hidden">
              <CardContent className="p-6">
                <div className="mb-4 flex size-10 items-center justify-center rounded-full bg-primary/15 font-bold text-primary">
                  {i + 1}
                </div>
                <h3 className="mb-2 text-lg font-semibold">{t(`steps.${step}.title`)}</h3>
                <p className="text-sm text-muted-foreground">{t(`steps.${step}.desc`)}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Container>
    </section>
  )
}

// ── Features ──────────────────────────────────────────────────────────────

function Features() {
  const { t } = useI18n()
  const features = [
    { icon: Shield, key: "safety" },
    { icon: Zap, key: "dev" },
    { icon: Search, key: "large" },
    { icon: Star, key: "fav" },
    { icon: BarChart3, key: "overview" },
    { icon: Trash2, key: "trash" },
  ]
  return (
    <section className="border-y border-border/60 bg-card/40 py-20">
      <Container>
        <SectionHeader title={t("features.title")} subtitle={t("features.subtitle")} />
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {features.map(({ icon: Icon, key }) => (
            <Card key={key} className="transition-colors hover:border-primary/40">
              <CardContent className="p-6">
                <div className="mb-4 flex size-11 items-center justify-center rounded-lg bg-primary/15">
                  <Icon className="size-5 text-primary" />
                </div>
                <h3 className="mb-2 font-semibold">{t(`features.${key}.title`)}</h3>
                <p className="text-sm text-muted-foreground">{t(`features.${key}.desc`)}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Container>
    </section>
  )
}

// ── Safety levels ─────────────────────────────────────────────────────────

function SafetyLevels() {
  const { t } = useI18n()
  const levels = [
    { key: "safe", variant: "success" as const, ring: "ring-emerald-400/30" },
    { key: "caution", variant: "warning" as const, ring: "ring-amber-400/30" },
    { key: "risky", variant: "danger" as const, ring: "ring-red-400/30" },
  ]
  return (
    <section className="py-20">
      <Container>
        <SectionHeader title={t("safety.title")} subtitle={t("safety.subtitle")} />
        <div className="grid gap-6 md:grid-cols-3">
          {levels.map(({ key, variant, ring }) => (
            <Card key={key} className={`ring-1 ${ring}`}>
              <CardContent className="p-6">
                <Badge variant={variant}>{t(`safety.${key}.tag`)}</Badge>
                <h3 className="mb-2 mt-4 font-semibold">{t(`safety.${key}.title`)}</h3>
                <p className="text-sm text-muted-foreground">{t(`safety.${key}.desc`)}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </Container>
    </section>
  )
}

// ── Download ──────────────────────────────────────────────────────────────

function DownloadSection() {
  const { t } = useI18n()
  return (
    <section id="download" className="pb-24">
      <Container>
        <Card className="mx-auto max-w-2xl border-primary/20 bg-gradient-to-b from-card to-secondary/40 text-center">
          <CardContent className="flex flex-col items-center px-5 py-10 sm:px-10">
            <img src="/icon.png" alt="Again Cleaner" width={80} height={80} className="mb-6 rounded-2xl shadow-xl" />
            <h2 className="text-3xl font-bold">{t("download.title")}</h2>
            <p className="mt-3 text-muted-foreground">{t("download.subtitle")}</p>
            <Button size="lg" className="mt-8 h-auto min-h-11 max-w-full whitespace-normal text-center" asChild>
              <a href="/Again-Cleaner.dmg" download>
                <Download />
                {t("download.btn")}
              </a>
            </Button>
            <div className="mt-4 flex flex-wrap items-center justify-center gap-2 text-xs text-muted-foreground">
              <span>{t("download.version")}</span>
              <span>·</span>
              <span>{t("download.requirements")}</span>
              <span>·</span>
              <span>{t("download.signed")}</span>
            </div>
            <ol className="mt-8 space-y-2 text-left text-sm text-muted-foreground">
              {[1, 2, 3].map((n) => (
                <li key={n} className="flex items-center gap-3">
                  <span className="flex size-6 shrink-0 items-center justify-center rounded-full bg-primary/15 text-xs font-bold text-primary">
                    {n}
                  </span>
                  {t(`download.step${n}`)}
                </li>
              ))}
            </ol>
          </CardContent>
        </Card>
      </Container>
    </section>
  )
}

// ── Developer credit (header + footer) ──────────────────────────────────

function DeveloperCredit({ className = "" }: { className?: string }) {
  const { t } = useI18n()
  return (
    <span className={`text-muted-foreground ${className}`}>
      {t("dev.by")}{" "}
      <a
        href="https://mediarise.org"
        target="_blank"
        rel="noopener"
        className="font-medium text-foreground underline-offset-4 hover:underline"
      >
        MediaRise
      </a>
    </span>
  )
}

// ── Footer ────────────────────────────────────────────────────────────────

function Footer() {
  const { t } = useI18n()
  return (
    <footer className="border-t border-border/60 py-10">
      <Container className="flex flex-col items-center justify-between gap-6 md:flex-row">
        <div className="flex items-center gap-3">
          <img src="/icon.png" alt="" width={32} height={32} className="rounded-lg" />
          <div className="text-sm">
            <strong>Again Cleaner</strong>
            <div className="text-muted-foreground">{t("footer.tagline")}</div>
            <DeveloperCredit />
          </div>
        </div>
        <nav className="flex flex-wrap items-center gap-6 text-sm text-muted-foreground">
          <a href="https://mediarise.org" target="_blank" rel="noopener" className="hover:text-foreground">
            MediaRise
          </a>
          <a href="https://github.com/digkill" target="_blank" rel="noopener" className="hover:text-foreground">
            GitHub
          </a>
          <a href="mailto:alexcatleva@gmail.com" className="hover:text-foreground">
            Contact
          </a>
        </nav>
        <p className="text-xs text-muted-foreground">© 2026 Digkill · MediaRise</p>
      </Container>
    </footer>
  )
}
