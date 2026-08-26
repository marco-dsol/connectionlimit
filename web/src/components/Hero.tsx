import { useEffect, useState } from 'react'
import { AppPanel, type Phase } from './AppPanel'
import { DOWNLOAD } from '../lib/download'

export function Hero() {
  const [phase, setPhase] = useState<Phase>(0)

  // Die Kopfzeile spielt die Geschichte einmal durch und bleibt dann beim
  // interessantesten Zustand stehen: Sperre gesetzt, und trotzdem fließt etwas.
  useEffect(() => {
    const stops: Phase[] = [1, 2, 3]
    const timers = stops.map((next, index) =>
      window.setTimeout(() => setPhase(next), 3200 + index * 4200),
    )
    return () => timers.forEach(window.clearTimeout)
  }, [])

  return (
    <header className="hero" id="top">
      <div className="wrap hero-grid">
        <div>
          <span className="eyebrow">Für macOS · Swift · quelloffen</span>
          <h1>
            Sehen, wer Datenvolumen<br />verbraucht — und es{' '}
            <span className="cut">abdrehen</span>.
          </h1>
          <p className="lead">
            macOS zeigt keinen Verbrauch pro App und hat keinen Low-Data-Modus wie iOS.
            ConnectionLimit schließt beide Lücken, soweit das ohne Apple-Sonderrechte
            geht — und sagt klar, wo die Grenze verläuft.
          </p>

          <div className="hero-actions">
            <a className="btn btn-primary" href={DOWNLOAD.file} download>
              <span aria-hidden>↓</span> Für macOS laden
            </a>
            <a className="btn btn-ghost" href="#demo">Live-Demo ansehen</a>
          </div>
          <p className="hero-fineprint">
            Version {DOWNLOAD.version} · {DOWNLOAD.size} · {DOWNLOAD.requires} ·
            {' '}Apple Silicon und Intel
          </p>

          <div className="hero-meta">
            <div><strong>Kein Konto</strong>keine Anmeldung, kein Dienst dahinter</div>
            <div><strong>Keine Ortung</strong>Netz an der Router-MAC</div>
            <div><strong>129 Prüfungen</strong>eigene Prüfsuite</div>
          </div>
        </div>

        <div className="hero-panel">
          <AppPanel phase={phase} />
          <p className="hero-panel-note">
            Kein Screenshot — das Menüleisten-Fenster, nachgebaut und in Bewegung.
          </p>
        </div>
      </div>
    </header>
  )
}
