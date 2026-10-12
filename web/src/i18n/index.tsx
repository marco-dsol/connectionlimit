import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { de, type Dict } from './de'
import { en } from './en'

/// Zwei Sprachen, ein Wörterbuch je Sprache. Das englische ist mit dem Typ
/// des deutschen gebaut — fehlt dort ein Eintrag, bricht der Build, statt
/// dass auf der Seite still ein deutsches Wort stehen bleibt.

export type Lang = 'de' | 'en'
export const LANGS: Lang[] = ['de', 'en']

const DICTS: Record<Lang, Dict> = { de, en }
const STORAGE_KEY = 'cl-lang'

function isLang(value: unknown): value is Lang {
  return value === 'de' || value === 'en'
}

/// Reihenfolge: ausdrücklicher Link (`?lang=`), dann die eigene frühere Wahl,
/// dann die Browsersprache. Ein geteilter Link soll in der Sprache ankommen,
/// in der er geteilt wurde — auch bei jemandem, der sonst die andere liest.
function initialLang(): Lang {
  try {
    const param = new URLSearchParams(window.location.search).get('lang')
    if (isLang(param)) return param
  } catch {
    /* ohne URL-Parameter weiter */
  }
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (isLang(stored)) return stored
  } catch {
    /* Speicher gesperrt (privates Fenster) — kein Grund zum Abbruch */
  }
  const browser = (navigator.languages?.[0] ?? navigator.language ?? '').toLowerCase()
  return browser.startsWith('de') ? 'de' : 'en'
}

interface LangContext {
  lang: Lang
  t: Dict
  setLang: (lang: Lang) => void
}

const Ctx = createContext<LangContext | null>(null)

export function LangProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(initialLang)
  const t = DICTS[lang]

  // Alles außerhalb von React mitziehen: Sprachattribut (Silbentrennung,
  // Vorlesefunktion), Titel, Beschreibung und die Adresse — damit ein
  // kopierter Link die gewählte Sprache mitnimmt.
  useEffect(() => {
    document.documentElement.lang = lang
    document.title = t.meta.title
    document.querySelector('meta[name="description"]')?.setAttribute('content', t.meta.description)
    try {
      const url = new URL(window.location.href)
      url.searchParams.set('lang', lang)
      window.history.replaceState(window.history.state, '', url)
    } catch {
      /* Adresse lässt sich nicht ändern (file://) — die Seite geht trotzdem */
    }
  }, [lang, t])

  const setLang = useCallback((next: Lang) => {
    setLangState(next)
    try {
      window.localStorage.setItem(STORAGE_KEY, next)
    } catch {
      /* siehe oben */
    }
  }, [])

  const value = useMemo(() => ({ lang, t, setLang }), [lang, t, setLang])
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useLang(): LangContext {
  const value = useContext(Ctx)
  if (!value) throw new Error('useLang() außerhalb von <LangProvider>')
  return value
}
