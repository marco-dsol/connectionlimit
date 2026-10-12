import { useEffect, useRef, useState } from 'react'
import { blockedIn, ROWS, type Phase, type RowId } from './AppPanel'
import { drift, useTicker } from '../hooks/useTicker'
import { bytes, clock, rate } from '../lib/format'
import { useReveal } from '../hooks/useReveal'
import { useLang } from '../i18n'
import type { Dict } from '../i18n/de'

/// Die Geschichte, die das Werkzeug erzählt — nachgespielt und anfassbar.
///
/// Vier Schritte laufen von selbst durch. Wer eingreift (sperrt, freigibt,
/// einen Schritt anklickt), übernimmt: Die Automatik hält an, bis er sie
/// wieder startet. Eine Demo, die weiterläuft, während man etwas ausprobiert,
/// nimmt einem die Sache aus der Hand.

/// Ein Protokolleintrag hält Zeitpunkt und Bedeutung fest, nicht den
/// fertigen Text — wer mitten in der Demo die Sprache wechselt, soll das
/// ganze Protokoll in der neuen Sprache sehen.
interface LogEntry {
  id: number
  at: Date
  kind: 'blocked' | 'released' | 'attempt' | 'info'
  text: (t: Dict) => string
}

export function LiveDemo() {
  const { t } = useLang()
  const reveal = useReveal<HTMLDivElement>()
  const [phase, setPhase] = useState<Phase>(0)
  const [running, setRunning] = useState(true)
  /// Vom Nutzer selbst gesetzte Zustände schlagen die Phase.
  const [manual, setManual] = useState<Record<string, boolean>>({})
  const [log, setLog] = useState<LogEntry[]>([])
  const logId = useRef(0)

  const push = (kind: LogEntry['kind'], text: LogEntry['text']) =>
    setLog((entries) =>
      [{ id: logId.current++, at: new Date(), kind, text }, ...entries].slice(0, 7))

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
    if (phase === 1) push('info', (d) => d.demo.events.network)
    if (phase === 2) {
      push('blocked', (d) => d.demo.events.icloud)
      const later = [
        window.setTimeout(() => push('blocked', (d) => d.demo.events.onedrive), 420),
        window.setTimeout(() => push('blocked', (d) => d.demo.events.update), 840),
      ]
      return () => later.forEach(window.clearTimeout)
    }
    if (phase === 3) push('attempt', (d) => d.demo.events.leak)
  }, [phase])

  const isBlocked = (id: string) =>
    manual[id] !== undefined ? manual[id] : blockedIn(phase, id)

  const toggle = (id: RowId) => {
    setRunning(false)
    const next = !isBlocked(id)
    setManual((m) => ({ ...m, [id]: next }))
    push(next ? 'blocked' : 'released', (d) => d.demo.events.manual(d.terms.rows[id]))
  }

  return (
    <section id="demo">
      <div className="wrap">
        <div className="section-head reveal" ref={reveal}>
          <span className="eyebrow">{t.demo.eyebrow}</span>
          <h2>{t.demo.title}</h2>
          <p className="lead">{t.demo.lead}</p>
        </div>

        <div className="demo-grid">
          <div className="card demo-stage">
            <TrackedList phase={phase} isBlocked={isBlocked} onToggle={toggle} />
          </div>

          <div>
            <div className="demo-steps">
              {t.demo.steps.map((step, index) => (
                <button
                  key={index}
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
                <span>{t.demo.log}</span>
                <button
                  className="pill"
                  style={{ cursor: 'pointer', border: 0 }}
                  onClick={() => {
                    setManual({})
                    setRunning((r) => !r)
                  }}
                >
                  {running ? t.demo.pause : t.demo.resume}
                </button>
              </div>
              {log.length === 0 ? (
                <p style={{ fontSize: '0.78rem', color: 'var(--faint)', padding: '8px 0' }}>
                  {t.demo.logEmpty}
                </p>
              ) : (
                log.map((entry) => (
                  <div className="log-row" key={entry.id}>
                    <span className="log-time">{clock(t.locale, entry.at)}</span>
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
                      {t.demo.kinds[entry.kind]}
                    </span>
                    <span className="log-what">{entry.text(t)}</span>
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
  onToggle: (id: RowId) => void
}) {
  const { t } = useLang()
  const w = t.terms
  const d = t.demo.tiles
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
        <Tile label={d.today} value={bytes(phase === 0 ? 3.11e8 : 4.42e8)} note={d.sinceMidnight} />
        <Tile
          label={d.now}
          value={totalRate > 0 ? rate(totalRate) : '—'}
          note={w.active(Object.values(rates).filter((r) => r > 0).length)}
          tone={totalRate > 0 ? 'green' : undefined}
        />
        <Tile label={d.watched} value={String(ROWS.length)} note={d.inList} />
        <Tile
          label={d.blocked}
          value={String(blockedCount)}
          note={leaking > 0 ? d.leaks(leaking) : d.noLeaks}
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
                  {w.rows[row.id]}
                  {leak && <span className="pill pill-amber">{w.despiteBlockLong}</span>}
                  {blocked && !leak && <span className="pill pill-red">{w.blocked}</span>}
                </div>
                <div className="bar">
                  <i style={{ width: `${Math.min(100, (row.total / 4.1e8) * 100)}%` }} />
                </div>
                <div className="svc-meta">
                  {w.classes[row.cls]} · {value > 0 ? w.activeNow : blocked ? w.paused : w.lastSeen}
                </div>
              </div>
              <div className="spark" style={{ color }}>
                {spark[row.id].map((v, i) => (
                  <i key={i} className={v <= 0.02 ? 'zero' : ''} style={{ height: `${Math.max(2, v * 24)}px` }} />
                ))}
              </div>
              <div className="svc-num">
                <b>{bytes(row.total)}</b>
                <span>{value > 0 ? rate(value) : w.idle}</span>
              </div>
              <button
                className={`row-btn ${blocked ? 'free' : ''}`}
                onClick={() => onToggle(row.id)}
              >
                {blocked ? w.unblock : w.block}
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
