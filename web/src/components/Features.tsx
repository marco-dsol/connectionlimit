import { useReveal } from '../hooks/useReveal'

const FEATURES = [
  {
    glow: 'var(--green)',
    icon: '👁',
    title: 'Dauerbeobachtung',
    text: 'Wer einmal Daten gebraucht hat, bleibt in der Liste — bis du zurücksetzt. Sonst könnte man genau das nicht sperren, was gerade still ist.',
  },
  {
    glow: 'var(--amber)',
    icon: '⚠',
    title: 'Durchbrüche mit Zeitpunkt',
    text: 'Fließen trotz gesetzter Sperre Daten, wird das mit Beginn, Ende und Menge protokolliert. Eine Sperre, die nicht hält, ist schlimmer als keine.',
  },
  {
    glow: 'var(--blue)',
    icon: '📈',
    title: 'Menge über die Zeit',
    text: 'Stunden- und Tagesfenster je Dienst. Stille Fenster stehen als Null da, statt zu fehlen — sonst sähe Ruhe wie schwacher Verkehr aus.',
  },
  {
    glow: 'var(--green)',
    icon: '📍',
    title: 'Das Netz sagt, dass Urlaub ist',
    text: 'Jedes Netz wird an der MAC-Adresse seines Routers wiedererkannt — ohne Ortungsdienste. Am Hotspot greift der Urlaubsmodus, zuhause fällt er von selbst weg.',
  },
  {
    glow: 'var(--amber)',
    icon: '🎚',
    title: 'Profile, die du selbst festlegst',
    text: 'Jede Stufe sperrt Klassen, keine einzelnen Dienste — so greift sie auch für Dienste, die es beim Anlegen noch nicht gab. Welche Klassen das sind, bestimmst du.',
  },
  {
    glow: 'var(--red)',
    icon: '🛟',
    title: 'Sicherheitsnetz',
    text: 'Quittung vor dem Eingriff, Aufräumen beim Start, im Zweifel freigeben. Und niemals den eigenen Prozess oder sein Terminal einfrieren.',
  },
]

export function Features() {
  const head = useReveal<HTMLDivElement>()
  return (
    <section id="funktionen">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">Funktionen</span>
          <h2>Sechs Dinge, die macOS nicht mitbringt</h2>
          <p className="lead">
            Gebaut für die Situation, in der Volumen knapp ist: Hotspot, Roaming,
            Hotel-Tarif.
          </p>
        </div>

        <div className="feature-grid">
          {FEATURES.map((feature, index) => (
            <Feature key={feature.title} feature={feature} delay={index * 70} />
          ))}
        </div>
      </div>
    </section>
  )
}

function Feature({
  feature,
  delay,
}: {
  feature: (typeof FEATURES)[number]
  delay: number
}) {
  const ref = useReveal<HTMLDivElement>(delay)
  return (
    <div
      className="feature reveal"
      ref={ref}
      style={{ ['--glow' as string]: feature.glow }}
    >
      <div className="feature-ico" aria-hidden>{feature.icon}</div>
      <h3>{feature.title}</h3>
      <p>{feature.text}</p>
    </div>
  )
}
