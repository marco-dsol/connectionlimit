import type { PointerEvent } from 'react'
import { useReveal } from '../hooks/useReveal'
import { useLang } from '../i18n'
import type { Card } from '../i18n/de'

/// Glanzfarbe und Symbol gehören zur Gestaltung, nicht zur Sprache — sie
/// stehen hier, die Texte im Wörterbuch, in derselben Reihenfolge.
const LOOK = [
  { glow: 'var(--green)', icon: '👁' },
  { glow: 'var(--amber)', icon: '⚠' },
  { glow: 'var(--blue)', icon: '📈' },
  { glow: 'var(--green)', icon: '📍' },
  { glow: 'var(--amber)', icon: '🎚' },
  { glow: 'var(--red)', icon: '🛟' },
]

export function Features() {
  const { t } = useLang()
  const head = useReveal<HTMLDivElement>()
  return (
    <section id="funktionen">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">{t.features.eyebrow}</span>
          <h2>{t.features.title}</h2>
          <p className="lead">{t.features.lead}</p>
        </div>

        <div className="feature-grid">
          {t.features.items.map((feature, index) => (
            <Feature key={index} feature={feature} look={LOOK[index]} delay={index * 70} />
          ))}
        </div>
      </div>
    </section>
  )
}

/// Die Karte folgt dem Zeiger mit einem weichen Lichtkegel. Gesetzt werden
/// nur zwei CSS-Variablen; das Licht selbst zeichnet CSS.
function spotlight(event: PointerEvent<HTMLDivElement>) {
  const node = event.currentTarget
  const box = node.getBoundingClientRect()
  node.style.setProperty('--mx', `${event.clientX - box.left}px`)
  node.style.setProperty('--my', `${event.clientY - box.top}px`)
}

function Feature({
  feature,
  look,
  delay,
}: {
  feature: Card
  look: (typeof LOOK)[number]
  delay: number
}) {
  const ref = useReveal<HTMLDivElement>(delay)
  return (
    <div
      className="feature reveal"
      ref={ref}
      onPointerMove={spotlight}
      style={{ ['--glow' as string]: look.glow }}
    >
      <div className="feature-ico" aria-hidden>{look.icon}</div>
      <h3>{feature.title}</h3>
      <p>{feature.text}</p>
    </div>
  )
}
