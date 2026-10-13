import { useEffect, useRef, useState, type PointerEvent } from 'react'
import { AppPanel, type Phase } from './AppPanel'
import { PacketStream } from './PacketStream'
import { Spot } from './Spot'
import { DOWNLOAD, downloadSize } from '../lib/download'
import { useLang } from '../i18n'

/// Höchste Neigung des Fenster-Nachbaus in Grad. Genug, dass er räumlich
/// wirkt; mehr, und die Zahlen darin werden schwer lesbar.
const MAX_TILT = 6

export function Hero() {
  const { t } = useLang()
  const [phase, setPhase] = useState<Phase>(0)
  const panelRef = useRef<HTMLDivElement>(null)

  // Die Kopfzeile spielt die Geschichte einmal durch und bleibt dann beim
  // interessantesten Zustand stehen: Sperre gesetzt, und trotzdem fließt etwas.
  useEffect(() => {
    const stops: Phase[] = [1, 2, 3]
    const timers = stops.map((next, index) =>
      window.setTimeout(() => setPhase(next), 3200 + index * 4200),
    )
    return () => timers.forEach(window.clearTimeout)
  }, [])

  // Neigung nur mit echter Maus: Auf Touch-Geräten gibt es kein Schweben,
  // und wer reduzierte Bewegung eingestellt hat, bekommt ein ruhiges Bild.
  const canTilt = () =>
    window.matchMedia('(hover: hover) and (pointer: fine)').matches
    && !window.matchMedia('(prefers-reduced-motion: reduce)').matches

  const onMove = (event: PointerEvent<HTMLDivElement>) => {
    const node = panelRef.current
    if (!node || event.pointerType !== 'mouse' || !canTilt()) return
    const box = node.getBoundingClientRect()
    const x = (event.clientX - box.left) / box.width - 0.5
    const y = (event.clientY - box.top) / box.height - 0.5
    node.style.setProperty('--ry', `${(x * MAX_TILT * 2).toFixed(2)}deg`)
    node.style.setProperty('--rx', `${(-y * MAX_TILT * 2).toFixed(2)}deg`)
    node.style.setProperty('--gx', `${((x + 0.5) * 100).toFixed(1)}%`)
    node.style.setProperty('--gy', `${((y + 0.5) * 100).toFixed(1)}%`)
    node.classList.add('tilting')
  }

  const onLeave = () => {
    const node = panelRef.current
    if (!node) return
    node.style.setProperty('--rx', '0deg')
    node.style.setProperty('--ry', '0deg')
    node.classList.remove('tilting')
  }

  return (
    <header className="hero" id="top">
      <PacketStream anchor={panelRef} />
      <div className="wrap hero-grid">
        <div>
          <span className="eyebrow">{t.hero.eyebrow}</span>
          <h1>
            {t.hero.titleLine1}<br />{t.hero.titleLine2}
            <span className="cut">{t.hero.titleCut}</span>{t.hero.titleEnd}
          </h1>
          <p className="lead">{t.hero.lead}</p>

          <div className="hero-actions">
            <Spot />
            <a className="btn btn-ghost" href={DOWNLOAD.file} download data-umami-event="download" data-umami-event-from="hero">
              <span aria-hidden>↓</span> {t.hero.cta}
            </a>
          </div>
          <p className="hero-fineprint">
            {t.hero.version} {DOWNLOAD.version} · {downloadSize(t.decimal)} · {t.download.requires} ·
            {' '}{t.download.architectures}
          </p>

          <div className="hero-meta">
            {t.hero.meta.map((item) => (
              <div key={item.strong}><strong>{item.strong}</strong>{item.text}</div>
            ))}
          </div>
        </div>

        <div className="hero-panel" ref={panelRef} onPointerMove={onMove} onPointerLeave={onLeave}>
          <div className="tilt">
            <AppPanel phase={phase} />
          </div>
          <p className="hero-panel-note">{t.hero.panelNote}</p>
        </div>
      </div>
    </header>
  )
}
