import { useEffect, useRef, useState } from 'react'
import { Wordmark } from './Logo'
import { DOWNLOAD, GITHUB_URL } from '../lib/download'
import { LANGS, useLang } from '../i18n'

export function Nav() {
  const { t } = useLang()
  const [stuck, setStuck] = useState(false)
  const nav = useRef<HTMLElement>(null)

  // Die Leseanzeige ist ein Datenbudget: Sie füllt sich beim Scrollen und
  // wird dabei von grün über orange nach rot — dieselbe Farbsprache wie in
  // der App. Gesetzt wird nur eine CSS-Variable, gezeichnet wird in CSS;
  // ein React-Render je Scrollereignis wäre Verschwendung.
  useEffect(() => {
    let frame = 0
    const update = () => {
      frame = 0
      const max = document.documentElement.scrollHeight - window.innerHeight
      const progress = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0
      nav.current?.style.setProperty('--progress', progress.toFixed(4))
      setStuck(window.scrollY > 12)
    }
    const onScroll = () => {
      if (!frame) frame = window.requestAnimationFrame(update)
    }
    update()
    window.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onScroll)
    return () => {
      window.removeEventListener('scroll', onScroll)
      window.removeEventListener('resize', onScroll)
      if (frame) window.cancelAnimationFrame(frame)
    }
  }, [])

  return (
    <nav ref={nav} className={stuck ? 'nav stuck' : 'nav'}>
      <div className="wrap nav-inner">
        <Wordmark />
        <div className="nav-links">
          <a href="#demo">{t.nav.demo}</a>
          <a href="#funktionen">{t.nav.features}</a>
          <a href="#fenster">{t.nav.window}</a>
          <a href="#terminal">{t.nav.terminal}</a>
          <a href="#grenzen">{t.nav.limits}</a>
          <a href="#loslegen">{t.nav.start}</a>
        </div>
        <div className="nav-actions">
          {GITHUB_URL && (
            <a className="nav-github" href={GITHUB_URL}>
              <GitHubMark /> GitHub
            </a>
          )}
          <LangSwitch />
          <a className="btn btn-primary btn-sm" href={DOWNLOAD.file} download>
            <span aria-hidden>↓</span> {t.nav.download}
          </a>
        </div>
      </div>
      <div className="nav-budget" role="presentation" aria-hidden />
    </nav>
  )
}

/// Das Octocat-Zeichen aus GitHubs eigenem Markenpaket; färbt sich über
/// `currentColor` mit dem Link mit.
function GitHubMark() {
  return (
    <svg viewBox="0 0 16 16" width="16" height="16" aria-hidden>
      <path
        fill="currentColor"
        d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"
      />
    </svg>
  )
}

/// Umschalter wie auf mitsol.at: zwei Segmente, das aktive hell hinterlegt.
/// Zwei Knöpfe mit `aria-pressed` statt eines Links — die Sprache wechselt
/// ohne Neuladen, und die Adresse zieht der Provider nach.
export function LangSwitch() {
  const { lang, t, setLang } = useLang()
  return (
    <div className="lang-switch" role="group" aria-label={t.lang.label}>
      {LANGS.map((code) => (
        <button
          key={code}
          type="button"
          lang={code}
          className={code === lang ? 'on' : ''}
          aria-pressed={code === lang}
          aria-label={t.lang.names[code]}
          title={t.lang.names[code]}
          onClick={() => setLang(code)}
        >
          {code.toUpperCase()}
        </button>
      ))}
    </div>
  )
}
