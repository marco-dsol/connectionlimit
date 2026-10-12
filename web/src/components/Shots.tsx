import { useEffect, useState } from 'react'
import { useReveal } from '../hooks/useReveal'
import { useLang } from '../i18n'

export function Shots() {
  const { t, lang } = useLang()
  const [active, setActive] = useState(0)
  /// Englische Aufnahmen liegen unter `screenshots/en/`, sobald
  /// `Tools/make-screenshots.sh en` gelaufen ist. Fehlt eine, springt die
  /// deutsche ein — und nur dann steht der Hinweis darunter. Ein Hinweis auf
  /// deutsche Bilder unter englischen Bildern wäre falsch.
  const [missing, setMissing] = useState<Record<string, boolean>>({})
  const head = useReveal<HTMLDivElement>()
  const frame = useReveal<HTMLDivElement>(120)
  const shot = t.shots.items[active]
  const localized = lang !== 'de' && !missing[shot.id]
  const src = localized ? `./screenshots/${lang}/${shot.id}.png` : `./screenshots/${shot.id}.png`

  useEffect(() => setMissing({}), [lang])

  return (
    <section id="fenster">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">{t.shots.eyebrow}</span>
          <h2>{t.shots.title}</h2>
          <p className="lead">{t.shots.lead}</p>
        </div>

        <div className="shot-tabs">
          {t.shots.items.map((entry, index) => (
            <button
              key={entry.id}
              className={`shot-tab ${index === active ? 'on' : ''}`}
              aria-pressed={index === active}
              onClick={() => setActive(index)}
            >
              {entry.label}
            </button>
          ))}
        </div>

        <div className="reveal" ref={frame}>
          <div className="shot-frame">
            <img
              key={src}
              className="swap"
              src={src}
              onError={() => localized && setMissing((m) => ({ ...m, [shot.id]: true }))}
              alt={t.shots.alt(shot.label)}
              loading="lazy"
            />
          </div>
          <p className="shot-caption">{shot.caption}</p>
          {lang !== 'de' && missing[shot.id] && t.shots.note && (
            <p className="shot-note">{t.shots.note}</p>
          )}
        </div>
      </div>
    </section>
  )
}
