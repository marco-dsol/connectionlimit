import { useEffect, useState } from 'react'
import { Wordmark } from './Logo'
import { DOWNLOAD, GITHUB_URL } from '../lib/download'

export function Nav() {
  const [stuck, setStuck] = useState(false)

  useEffect(() => {
    const onScroll = () => setStuck(window.scrollY > 12)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <nav className={stuck ? 'nav stuck' : 'nav'}>
      <div className="wrap nav-inner">
        <Wordmark />
        <div className="nav-links">
          <a href="#demo">Live-Demo</a>
          <a href="#funktionen">Funktionen</a>
          <a href="#fenster">Das Fenster</a>
          <a href="#terminal">Terminal</a>
          <a href="#grenzen">Grenzen</a>
          <a href="#loslegen">Loslegen</a>
        </div>
        <div className="nav-actions">
          {GITHUB_URL && (
            <a className="nav-github" href={GITHUB_URL}>Quelltext</a>
          )}
          <a className="btn btn-primary btn-sm" href={DOWNLOAD.file} download>
            <span aria-hidden>↓</span> Laden
          </a>
        </div>
      </div>
    </nav>
  )
}
