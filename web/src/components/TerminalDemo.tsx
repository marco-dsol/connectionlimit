import { useEffect, useRef, useState } from 'react'
import { useReveal } from '../hooks/useReveal'

/// Dasselbe Werkzeug im Terminal — abgetippt, wie es wirklich antwortet.
/// Die Ausgaben stammen aus einem echten Lauf; gekürzt, nicht geschönt.

interface Line {
  text: string
  tone?: 'dim' | 'green' | 'red' | 'amber' | 'head'
}

const PROGRAMS: { command: string; lines: Line[] }[] = [
  {
    command: 'connlimit tracked',
    lines: [
      { text: 'Getrackte Dienste  ·  seit 25.08. 17:01  ·  Netz: iPhone von Marco [teuer]', tone: 'dim' },
      { text: '' },
      { text: '  DIENST                KLASSE          GESAMT     HEUTE  ZULETZT   VERLAUF 24 h', tone: 'head' },
      { text: '● Google Chrome         Browser       412.7 MB  26.4 MB  gerade    ▁▂▃▅█▆▃▂▁▁▂▃', tone: 'green' },
      { text: '● Microsoft Outlook     E-Mail        119.3 MB  12.1 MB  gerade    ▂▃▂▁▁▂▅▃▂▁▁▁', tone: 'green' },
      { text: '⚠ OneDrive              Cloud-Sync     64.0 MB   1.4 MB  gerade    ▁▁▁▂▁▁▁▂▁▁▁▁', tone: 'amber' },
      { text: '  ↳ 3× trotz Sperre aktiv · 1.4 MB · zuletzt 12:04', tone: 'dim' },
      { text: '🔒 iCloud Fotos         Cloud-Sync    180.2 MB       —  vor 8 min ▃▅▂▁▁·······', tone: 'red' },
      { text: '  macOS Update          Updates        29.0 MB       —  vor 39 min▁▁·········', tone: 'dim' },
      { text: '' },
      { text: 'Gesamt: 805.2 MB  ·  25 Dienste  ·  3 gerade aktiv', tone: 'dim' },
    ],
  },
  {
    command: 'connlimit events --attempts',
    lines: [
      { text: 'Protokoll  ·  seit 18.08. 12:04', tone: 'dim' },
      { text: '' },
      { text: '  12:04–12:19       trotz Sperre aktiv  OneDrive        1.4 MB', tone: 'amber' },
      { text: '  09:31–09:33       trotz Sperre aktiv  iCloud Fotos    240 kB', tone: 'amber' },
      { text: '  gestern 21:12     trotz Sperre aktiv  OneDrive        780 kB', tone: 'amber' },
      { text: '' },
      { text: 'Eine Sperre, durch die etwas durchkommt, ist schlimmer als keine —', tone: 'dim' },
      { text: 'weil man sich auf sie verlässt. Deshalb steht sie hier.', tone: 'dim' },
    ],
  },
  {
    command: 'connlimit profile edit sparsam update backup media',
    lines: [
      { text: '✓ Sparsam sperrt jetzt: Updates, Backup, Medien', tone: 'green' },
      { text: '   freigegeben: telemetry', tone: 'dim' },
      { text: '' },
      { text: '$ connlimit profile', tone: 'dim' },
      { text: '  ● Aus             —', tone: 'dim' },
      { text: '  ○ Sparsam         Updates, Backup, Medien  ✎', tone: 'amber' },
      { text: '  ○ Urlaubsmodus    Updates, Backup, Telemetrie, Medien, Cloud-Sync', tone: 'dim' },
      { text: '  ○ Notfall         … zusätzlich E-Mail, Browser', tone: 'dim' },
    ],
  },
]

export function TerminalDemo() {
  const head = useReveal<HTMLDivElement>()
  const box = useReveal<HTMLDivElement>(100)
  const [program, setProgram] = useState(0)
  const [typed, setTyped] = useState('')
  const [shown, setShown] = useState(0)
  const timers = useRef<number[]>([])

  useEffect(() => {
    const current = PROGRAMS[program]
    setTyped('')
    setShown(0)
    timers.current.forEach(window.clearTimeout)
    timers.current = []

    const plan = (delay: number, action: () => void) => {
      timers.current.push(window.setTimeout(action, delay))
    }

    // Befehl tippen …
    for (let i = 1; i <= current.command.length; i++) {
      plan(i * 42, () => setTyped(current.command.slice(0, i)))
    }
    const typingDone = current.command.length * 42 + 380

    // … dann die Antwort zeilenweise ausgeben.
    current.lines.forEach((_, index) => {
      plan(typingDone + index * 95, () => setShown(index + 1))
    })

    const finished = typingDone + current.lines.length * 95 + 3600
    plan(finished, () => setProgram((p) => (p + 1) % PROGRAMS.length))

    return () => timers.current.forEach(window.clearTimeout)
  }, [program])

  const current = PROGRAMS[program]

  return (
    <section id="terminal">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">Terminal</span>
          <h2>Alles, was das Fenster kann, kann auch die Kommandozeile</h2>
          <p className="lead">
            Dieselbe Datenbank, dieselben Regeln. Wer lieber tippt, verpasst nichts.
          </p>
        </div>

        <div className="reveal" ref={box}>
          <div className="term">
            <div className="term-bar">
              <i style={{ background: '#ff5f56' }} />
              <i style={{ background: '#ffbd2e' }} />
              <i style={{ background: '#27c93f' }} />
              <span className="term-title">marco@macbook — connlimit</span>
            </div>
            <div className="term-body">
              <div>
                <span className="prompt">$</span> {typed}
                {shown === 0 && <span className="caret" />}
              </div>
              {current.lines.slice(0, shown).map((line, index) => (
                <div key={index} className={line.tone ? `t-${line.tone}` : undefined}>
                  {line.text || ' '}
                </div>
              ))}
              {shown > 0 && shown === current.lines.length && (
                <div>
                  <span className="prompt">$</span> <span className="caret" />
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
