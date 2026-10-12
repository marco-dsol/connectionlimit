import { useEffect, useMemo, useState } from 'react'
import { drift, useTicker } from '../hooks/useTicker'
import { bytes, rate } from '../lib/format'
import { useLang } from '../i18n'

/// Nachbau des Menüleisten-Fensters. Kein Bild, sondern echtes Markup: Die
/// Zahlen laufen, die Balken wachsen, die Zustände wechseln — wer die Seite
/// ansieht, hat die App schon einmal in Betrieb gesehen.

export type Phase = 0 | 1 | 2 | 3

export type RowId = 'chrome' | 'icloud' | 'onedrive' | 'update' | 'signal'
export type RowClass = 'browser' | 'sync' | 'update' | 'messaging'

/// Namen und Klassen stehen im Wörterbuch — „iCloud Fotos“ heißt auf
/// Englisch anders, und die Klassen sollen wie in der App heißen.
export interface Row {
  id: RowId
  cls: RowClass
  glyph: string
  total: number
  /** Byte/s in Ruhe bzw. unter Last. 0 heißt: still. */
  idle: number
  busy: number
}

export const ROWS: Row[] = [
  { id: 'chrome', cls: 'browser', glyph: '🌐', total: 4.1e8, idle: 900, busy: 2.4e6 },
  { id: 'icloud', cls: 'sync', glyph: '↻', total: 1.8e8, idle: 0, busy: 1.1e6 },
  { id: 'onedrive', cls: 'sync', glyph: '↻', total: 6.4e7, idle: 0, busy: 7.2e5 },
  { id: 'update', cls: 'update', glyph: '↓', total: 2.9e7, idle: 0, busy: 3.1e6 },
  { id: 'signal', cls: 'messaging', glyph: '💬', total: 2.1e6, idle: 220, busy: 4.8e4 },
]

/// Was in welcher Phase gesperrt ist. Ab Phase 2 greift der Urlaubsmodus:
/// Cloud-Sync und Updates. `onedrive` kommt trotzdem durch — der Fall, den
/// diese App als einzige überhaupt zeigt.
export function blockedIn(phase: Phase, id: string): boolean {
  if (phase < 2) return false
  return id === 'icloud' || id === 'onedrive' || id === 'update'
}

export function AppPanel({ phase }: { phase: Phase }) {
  const { t } = useLang()
  const w = t.terms
  const tick = useTicker(1100)
  const [rates, setRates] = useState<Record<string, number>>(() =>
    Object.fromEntries(ROWS.map((r) => [r.id, r.idle])),
  )
  const [spark, setSpark] = useState<Record<string, number[]>>(() =>
    Object.fromEntries(ROWS.map((r) => [r.id, Array.from({ length: 18 }, () => Math.random() * 0.35)])),
  )

  useEffect(() => {
    setRates((previous) => {
      const next: Record<string, number> = {}
      for (const row of ROWS) {
        const blocked = blockedIn(phase, row.id)
        const leaking = phase === 3 && row.id === 'onedrive'
        const ceiling = blocked ? (leaking ? row.busy * 0.22 : 0) : row.busy
        const floor = blocked ? 0 : row.idle
        next[row.id] = ceiling === 0 ? 0 : drift(previous[row.id] || floor, floor, ceiling)
      }
      return next
    })
    setSpark((previous) => {
      const next: Record<string, number[]> = {}
      for (const row of ROWS) {
        const series = previous[row.id].slice(1)
        const blocked = blockedIn(phase, row.id)
        const leaking = phase === 3 && row.id === 'onedrive'
        series.push(blocked ? (leaking ? Math.random() * 0.3 : 0) : 0.25 + Math.random() * 0.75)
        next[row.id] = series
      }
      return next
    })
  }, [tick, phase])

  const total = useMemo(() => Object.values(rates).reduce((a, b) => a + b, 0), [rates])
  const blockedRows = ROWS.filter((r) => blockedIn(phase, r.id))
  const activeTier = phase === 0 ? 0 : 2

  return (
    <div className="panel">
      <div className="panel-head">
        <div>
          <div className="panel-net">
            <span aria-hidden>{phase === 0 ? '📶' : '⚠️'}</span>
            {phase === 0 ? w.netHome : w.netHotspot}
          </div>
          <div className="panel-sub">
            {total > 0 && <span className="dot" aria-hidden />}
            {w.today(bytes(phase === 0 ? 3.1e8 : 4.4e8))} · {total > 0 ? rate(total) : w.quiet}
          </div>
        </div>
        <span className={phase === 0 ? 'pill pill-green' : 'pill pill-red'}>
          {phase === 0 ? w.free : w.metered}
        </span>
      </div>

      {phase >= 1 && (
        <div className="callout" key={phase >= 3 ? 'leak' : 'net'}>
          <span aria-hidden>{phase >= 3 ? '⚠' : 'ℹ'}</span>
          <span>
            {phase >= 3
              ? t.panel.calloutLeak
              : t.panel.calloutNet}
          </span>
        </div>
      )}

      <div className="panel-section">
        <div className="panel-label">
          <span>{t.panel.profile}</span>
          {phase >= 1 && <span className="pill pill-amber">{t.panel.automatic}</span>}
        </div>
        <div className="seg">
          {w.tiers.map((name, index) => (
            <button
              key={name}
              type="button"
              tabIndex={-1}
              className={index === activeTier ? (index === 0 ? 'on' : 'on warn') : ''}
            >
              {name}
            </button>
          ))}
        </div>
        <div style={{ fontSize: '0.72rem', color: 'var(--muted)' }}>
          {activeTier === 0
            ? w.tierNone
            : w.tierVacation}
        </div>
      </div>

      <div className="panel-section">
        <div className="panel-label">
          <span>{t.panel.services}</span>
          <span style={{ color: 'var(--green)' }}>
            {w.active(Object.values(rates).filter((r) => r > 0).length)}
          </span>
        </div>
        {ROWS.map((row) => {
          const value = rates[row.id] || 0
          const blocked = blockedIn(phase, row.id)
          const leak = blocked && value > 0
          const state = leak ? 'leak' : blocked ? 'blocked' : value > 0 ? 'active' : ''
          const color = leak ? 'var(--amber)' : blocked ? 'var(--red)' : value > 0 ? 'var(--green)' : 'var(--muted)'
          return (
            <div className={`svc ${state}`} key={row.id}>
              <span className="svc-ico" aria-hidden>{blocked ? '🔒' : row.glyph}</span>
              <div className="svc-body">
                <div className="svc-name">
                  {w.rows[row.id]}
                  {leak && <span className="pill pill-amber">{w.despiteBlock}</span>}
                </div>
                <div className="bar">
                  <i style={{ width: `${Math.min(100, (row.total / 4.1e8) * 100)}%` }} />
                </div>
              </div>
              <div className="spark" style={{ color }}>
                {spark[row.id].map((v, i) => (
                  <i key={i} className={v <= 0.02 ? 'zero' : ''} style={{ height: `${Math.max(2, v * 22)}px` }} />
                ))}
              </div>
              <div className="svc-num">
                <b>{bytes(row.total)}</b>
                <span>{value > 0 ? rate(value) : blocked ? w.blocked : w.idle}</span>
              </div>
            </div>
          )
        })}
      </div>

      {blockedRows.length > 0 && (
        <div className="panel-section">
          <div className="panel-label">
            <span>{t.panel.blockedHead(blockedRows.length)}</span>
            <span>{t.panel.releaseAll}</span>
          </div>
          <div style={{ marginTop: 8, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {blockedRows.map((row) => (
              <span className="pill pill-red" key={row.id}>🔒 {w.rows[row.id]}</span>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
