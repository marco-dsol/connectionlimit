import { useEffect, useRef, useState } from 'react'
import { blockedIn, ROWS, type Phase } from './AppPanel'
import { drift, useTicker } from '../hooks/useTicker'
import { bytes, clock, rate } from '../lib/format'
import { useReveal } from '../hooks/useReveal'

/// Die Geschichte, die das Werkzeug erzählt — nachgespielt und anfassbar.
///
/// Vier Schritte laufen von selbst durch. Wer eingreift (sperrt, freigibt,
/// einen Schritt anklickt), übernimmt: Die Automatik hält an, bis er sie
/// wieder startet. Eine Demo, die weiterläuft, während man etwas ausprobiert,
/// nimmt einem die Sache aus der Hand.

const STEPS: { title: string; text: string }[] = [
  {
    title: 'Zuhause: alles läuft',
    text: 'Freies WLAN, keine Sperren. Das Werkzeug misst nur — wer Daten braucht, landet in der Liste und bleibt dort stehen.',
  },
  {
    title: 'Am Hotspot: das Netz sagt Bescheid',
    text: 'Der Router wird an seiner MAC-Adresse wiedererkannt und ist als „teuer“ eingestuft. Der Urlaubsmodus greift von selbst — ohne dass jemand daran denken muss.',
  },
  {
    title: 'Sperren greifen',
    text: 'Cloud-Sync und Updates werden angehalten. Jede Sperre bekommt eine Quittung in der Datenbank, bevor sie gesetzt wird.',
  },
  {
    title: 'Ein Durchbruch wird protokolliert',
    text: 'OneDrive bewegt trotz Sperre Daten. Zeitpunkt und Menge stehen im Protokoll — eine Sperre, die nicht hält, ist schlimmer als keine.',
  },
]

interface LogEntry {
  id: number
  time: string
  kind: 'blocked' | 'released' | 'attempt' | 'info'
  text: string
}

const KIND_LABEL: Record<LogEntry['kind'], string> = {
  blocked: 'gesperrt',
  released: 'freigegeben',
  attempt: 'trotz Sperre aktiv',
  info: 'Netzwechsel',
}

export function LiveDemo() {
  const reveal = useReveal<HTMLDivElement>()
  const [phase, setPhase] = useState<Phase>(0)
  const [running, setRunning] = useState(true)
  /// Vom Nutzer selbst gesetzte Zustände schlagen die Phase.
  const [manual, setManual] = useState<Record<string, boolean>>({})
  const [log, setLog] = useState<LogEntry[]>([])
  const logId = useRef(0)

  const push = (kind: LogEntry['kind'], text: string) =>
    setLog((entries) =>
      [{ id: logId.current++, time: clock(), kind, text }, ...entries].slice(0, 7))

  // Automatischer Durchlauf.
  useEffect(() => {
    if (!running) return
    const id = window.setInterval(() => {
      setPhase((p) => ((p + 1) % 4) as Phase)
    }, 6500)
    return () => window.clearInterval(id)
  }, [running])

  // Was in dieser Phase passiert, landet im Protokoll.
  useEffect(() => {
    if (phase === 0) {
      setLog([])
      setManual({})
      return
    }
    if (phase === 1) push('info', 'iPhone von Marco · als teuer eingestuft → Urlaubsmodus')
    if (phase === 2) {
      push('blocked', 'iCloud Fotos · Systemdienst anhalten')
      window.setTimeout(() => push('blocked', 'OneDrive · App einfrieren'), 420)
      window.setTimeout(() => push('blocked', 'macOS Update · Systemdienst anhalten'), 840)
    }
    if (phase === 3) push('attempt', 'OneDrive · 1.4 MB seit 12 Minuten')
  }, [phase])

  const isBlocked = (id: string) =>
    manual[id] !== undefined ? manual[id] : blockedIn(phase, id)

  const toggle = (id: string, name: string) => {
    setRunning(false)
    const next = !isBlocked(id)
    setManual((m) => ({ ...m, [id]: next }))
    push(next ? 'blocked' : 'released', `${name} · von Hand`)
  }

  return (
    <section id="demo">
      <div className="wrap">
        <div className="section-head reveal" ref={reveal}>
          <span className="eyebrow">Live-Demo</span>
          <h2>Vier Schritte, wie es im Urlaub wirklich läuft</h2>
          <p className="lead">
            Kein Video, kein Bild: die Oberfläche selbst, nachgebaut und in Bewegung.
            Sperren lässt sich hier auch von Hand — dann übernimmst du.
          </p>
        </div>

        <div className="demo-grid">
          <div className="card demo-stage">
            <TrackedList phase={phase} isBlocked={isBlocked} onToggle={toggle} />
          </div>

          <div>
            <div className="demo-steps">
              {STEPS.map((step, index) => (
                <button
                  key={step.title}
                  className={`step ${index === phase ? 'on' : ''}`}
                  onClick={() => {
                    setRunning(false)
                    setManual({})
                    setPhase(index as Phase)
                  }}
                >
                  <span className="step-n">{index + 1}</span>
                  <span>
                    <h3>{step.title}</h3>
                    <p>{step.text}</p>
                    {index === phase && running && <span className="step-progress" />}
                  </span>
                </button>
              ))}
            </div>

            <div className="card" style={{ marginTop: 14, padding: '14px 16px' }}>
              <div className="panel-label" style={{ marginBottom: 6 }}>
                <span>Protokoll</span>
                <button
                  className="pill"
                  style={{ cursor: 'pointer', border: 0 }}
                  onClick={() => {
                    setManual({})
                    setRunning((r) => !r)
                  }}
                >
                  {running ? '❚❚ anhalten' : '▶ weiterlaufen'}
                </button>
              </div>
              {log.length === 0 ? (
                <p style={{ fontSize: '0.78rem', color: 'var(--faint)', padding: '8px 0' }}>
                  Noch nichts protokolliert. Sperren, Freigaben und Durchbrüche stehen hier
                  mit Zeitpunkt.
                </p>
              ) : (
                log.map((entry) => (
                  <div className="log-row" key={entry.id}>
                    <span className="log-time">{entry.time}</span>
                    <span
                      className={
                        entry.kind === 'attempt'
                          ? 'pill pill-amber'
                          : entry.kind === 'blocked'
                            ? 'pill pill-red'
                            : entry.kind === 'released'
                              ? 'pill pill-green'
                              : 'pill pill-blue'
                      }
                    >
                      {KIND_LABEL[entry.kind]}
                    </span>
                    <span className="log-what">{entry.text}</span>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/// Der Nachbau der Dauerliste aus dem Fenster.
function TrackedList({
  phase,
  isBlocked,
  onToggle,
}: {
  phase: Phase
  isBlocked: (id: string) => boolean
  onToggle: (id: string, name: string) => void
}) {
  const tick = useTicker(1000)
  const [rates, setRates] = useState<Record<string, number>>(() =>
    Object.fromEntries(ROWS.map((r) => [r.id, r.idle])),
  )
  const [spark, setSpark] = useState<Record<string, number[]>>(() =>
    Object.fromEntries(ROWS.map((r) => [r.id, Array.from({ length: 22 }, () => Math.random() * 0.4)])),
  )

  useEffect(() => {
    setRates((previous) => {
      const next: Record<string, number> = {}
      for (const row of ROWS) {
        const blocked = isBlocked(row.id)
        const leaking = phase === 3 && row.id === 'onedrive' && blocked
        const ceiling = blocked ? (leaking ? row.busy * 0.2 : 0) : row.busy
        next[row.id] = ceiling === 0 ? 0 : drift(previous[row.id] || row.idle, blocked ? 0 : row.idle, ceiling)
      }
      return next
    })
    setSpark((previous) => {
      const next: Record<string, number[]> = {}
      for (const row of ROWS) {
        const series = previous[row.id].slice(1)
        const blocked = isBlocked(row.id)
        const leaking = phase === 3 && row.id === 'onedrive' && blocked
        series.push(blocked ? (leaking ? Math.random() * 0.28 : 0) : 0.2 + Math.random() * 0.8)
        next[row.id] = series
      }
      return next
    })
    // `isBlocked` ändert sich mit jeder Eingabe; der Takt allein soll rechnen.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tick, phase])

  const totalRate = Object.values(rates).reduce((a, b) => a + b, 0)
  const blockedCount = ROWS.filter((r) => isBlocked(r.id)).length
  const leaking = ROWS.filter((r) => isBlocked(r.id) && (rates[r.id] || 0) > 0).length

  return (
    <div className="win">
      <div className="win-stats">
        <Tile label="Heute" value={bytes(phase === 0 ? 3.11e8 : 4.42e8)} note="seit Mitternacht" />
        <Tile
          label="Gerade"
          value={totalRate > 0 ? rate(totalRate) : '—'}
          note={`${Object.values(rates).filter((r) => r > 0).length} aktiv`}
          tone={totalRate > 0 ? 'green' : undefined}
        />
        <Tile label="Beobachtet" value={String(ROWS.length)} note="Dienste in der Liste" />
        <Tile
          label="Gesperrt"
          value={String(blockedCount)}
          note={leaking > 0 ? `${leaking} mit Durchbruch` : 'keine Durchbrüche'}
          tone={leaking > 0 ? 'amber' : blockedCount > 0 ? 'red' : undefined}
        />
      </div>

      <div className="win-rows">
        {ROWS.map((row) => {
          const value = rates[row.id] || 0
          const blocked = isBlocked(row.id)
          const leak = blocked && value > 0
          const state = leak ? 'leak' : blocked ? 'blocked' : value > 0 ? 'active' : ''
          const color = leak ? 'var(--amber)' : blocked ? 'var(--red)' : value > 0 ? 'var(--green)' : 'var(--muted)'
          return (
            <div className={`svc trow ${state}`} key={row.id}>
              <span className="svc-ico" aria-hidden>{blocked ? '🔒' : row.glyph}</span>
              <div className="svc-body">
                <div className="svc-name">
                  {row.name}
                  {leak && <span className="pill pill-amber">trotz Sperre aktiv</span>}
                  {blocked && !leak && <span className="pill pill-red">gesperrt</span>}
                </div>
                <div className="bar">
                  <i style={{ width: `${Math.min(100, (row.total / 4.1e8) * 100)}%` }} />
                </div>
                <div className="svc-meta">
                  {row.cls} · {value > 0 ? 'gerade aktiv' : blocked ? 'angehalten' : 'zuletzt vor 4 min'}
                </div>
              </div>
              <div className="spark" style={{ color }}>
                {spark[row.id].map((v, i) => (
                  <i key={i} className={v <= 0.02 ? 'zero' : ''} style={{ height: `${Math.max(2, v * 24)}px` }} />
                ))}
              </div>
              <div className="svc-num">
                <b>{bytes(row.total)}</b>
                <span>{value > 0 ? rate(value) : 'still'}</span>
              </div>
              <button
                className={`row-btn ${blocked ? 'free' : ''}`}
                onClick={() => onToggle(row.id, row.name)}
              >
                {blocked ? 'Freigeben' : 'Sperren'}
              </button>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function Tile({
  label,
  value,
  note,
  tone,
}: {
  label: string
  value: string
  note: string
  tone?: 'green' | 'red' | 'amber'
}) {
  return (
    <div className="tile">
      <span className="tile-label">{label}</span>
      <strong className={tone ? `tone-${tone}` : ''}>{value}</strong>
      <span className="tile-note">{note}</span>
    </div>
  )
}
