import { useState } from 'react'
import { useReveal } from '../hooks/useReveal'

const SHOTS = [
  {
    id: 'verbrauch',
    label: 'Verbrauch',
    caption: 'Die Dauerliste. Grün heißt „bewegt gerade Daten“, rot „gesperrt“, orange „gesperrt, und trotzdem fließt etwas“.',
  },
  {
    id: 'profile',
    label: 'Profile',
    caption: 'Jede Stufe sperrt Klassen. Welche das sind, legst du hier fest — die Voreinstellung ist nur ein Vorschlag.',
  },
  {
    id: 'protokoll',
    label: 'Protokoll',
    caption: 'Wann gesperrt, wann freigegeben, wann trotz Sperre etwas durchkam. Mit Zeitpunkt und Menge.',
  },
  {
    id: 'dienste',
    label: 'Dienste',
    caption: 'Der Katalog: was das Werkzeug kennt und mit welchem Hebel es den Dienst stoppt — samt Warnung, wie grob der Hebel wirkt.',
  },
  {
    id: 'budget',
    label: 'Budget',
    caption: 'Reisebudget mit Tagesration und Hochrechnung. Nur Verbrauch in teuren Netzen zählt.',
  },
]

export function Shots() {
  const [active, setActive] = useState(0)
  const head = useReveal<HTMLDivElement>()
  const frame = useReveal<HTMLDivElement>(120)
  const shot = SHOTS[active]

  return (
    <section id="fenster">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">Das Fenster</span>
          <h2>Echte Bildschirmfotos, nichts nachgezeichnet</h2>
          <p className="lead">
            Aufgenommen auf einem laufenden Mac. Die Zahlen sind echte Messwerte.
          </p>
        </div>

        <div className="shot-tabs">
          {SHOTS.map((entry, index) => (
            <button
              key={entry.id}
              className={`shot-tab ${index === active ? 'on' : ''}`}
              onClick={() => setActive(index)}
            >
              {entry.label}
            </button>
          ))}
        </div>

        <div className="reveal" ref={frame}>
          <div className="shot-frame">
            <img
              key={shot.id}
              className="swap"
              src={`./screenshots/${shot.id}.png`}
              alt={`ConnectionLimit — Bereich ${shot.label}`}
              loading="lazy"
            />
          </div>
          <p className="shot-caption">{shot.caption}</p>
        </div>
      </div>
    </section>
  )
}
