import { useEffect, useRef, useState } from 'react'
import { useReveal } from '../hooks/useReveal'
import { useLang } from '../i18n'

/// Dasselbe Werkzeug im Terminal — abgetippt, wie es wirklich antwortet.
/// Die Ausgaben stammen aus einem echten Lauf; gekürzt, nicht geschönt.
/// Sie stehen im Wörterbuch, weil die englische Kommandozeile anders antwortet.

export function TerminalDemo() {
  const { t } = useLang()
  const programs = t.terminal.programs
  const head = useReveal<HTMLDivElement>()
  const box = useReveal<HTMLDivElement>(100)
  const [program, setProgram] = useState(0)
  const [typed, setTyped] = useState('')
  const [shown, setShown] = useState(0)
  const timers = useRef<number[]>([])

  // Hängt auch an der Sprache: Beim Wechsel wird von vorn getippt — eine halb
  // deutsche, halb englische Ausgabe hat es so nie gegeben.
  useEffect(() => {
    const current = programs[program]
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
    plan(finished, () => setProgram((p) => (p + 1) % programs.length))

    return () => timers.current.forEach(window.clearTimeout)
  }, [program, programs])

  const current = programs[program]

  return (
    <section id="terminal">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">{t.terminal.eyebrow}</span>
          <h2>{t.terminal.title}</h2>
          <p className="lead">{t.terminal.lead}</p>
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
