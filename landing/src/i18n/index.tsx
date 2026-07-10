import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react"
import data from "./translations.json"

export const LANGS = ["en", "ru", "th", "zh", "ko"] as const
export type Lang = (typeof LANGS)[number]

export const LANG_NAMES: Record<Lang, string> = {
  en: "English",
  ru: "Русский",
  th: "ไทย",
  zh: "中文",
  ko: "한국어",
}

const translations = data.translations as Record<Lang, Record<string, string>>
const pageTitles = data.pageTitles as Record<Lang, string>

const STORAGE_KEY = "againCleanerLang"

function detectLang(): Lang {
  const saved = localStorage.getItem(STORAGE_KEY)
  if (saved && (LANGS as readonly string[]).includes(saved)) return saved as Lang
  const nav = navigator.language.slice(0, 2).toLowerCase()
  return (LANGS as readonly string[]).includes(nav) ? (nav as Lang) : "en"
}

interface I18nContextValue {
  lang: Lang
  setLang: (lang: Lang) => void
  t: (key: string) => string
}

const I18nContext = createContext<I18nContextValue | null>(null)

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(detectLang)

  const setLang = useCallback((next: Lang) => {
    setLangState(next)
    localStorage.setItem(STORAGE_KEY, next)
  }, [])

  useEffect(() => {
    document.documentElement.lang = lang
    document.title = pageTitles[lang] ?? pageTitles.en
  }, [lang])

  const t = useCallback(
    (key: string) => translations[lang]?.[key] ?? translations.en[key] ?? key,
    [lang]
  )

  return (
    <I18nContext.Provider value={{ lang, setLang, t }}>
      {children}
    </I18nContext.Provider>
  )
}

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext)
  if (!ctx) throw new Error("useI18n must be used within I18nProvider")
  return ctx
}
