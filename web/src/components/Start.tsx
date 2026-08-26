import { useState } from 'react'
import { useReveal } from '../hooks/useReveal'
import { DOWNLOAD, GITHUB_URL } from '../lib/download'

interface Step {
  title: string
  text: string
  code?: string
  codeNote?: string
}

const GATEKEEPER_STEP: Step = {
  title: 'Beim ersten Start: Rechtsklick › Öffnen',
  text: 'Das Programm ist nicht bei Apple notarisiert — ein Doppelklick wird deshalb '
      + 'zunächst abgelehnt. Über das Kontextmenü einmal „Öffnen“ wählen, danach '
      + 'startet es wie jedes andere.',
  code: 'xattr -d com.apple.quarantine /Applications/ConnectionLimit.app',
  codeNote: 'Wer den Weg über das Terminal bevorzugt',
}

/// Ist das Paket notarisiert, fällt der Umweg über das Kontextmenü weg — und
/// mit ihm der ganze Schritt. Ein Hinweis, der nicht mehr stimmt, ist
/// schlimmer als keiner.
const STEPS: Step[] = [
  {
    title: 'Laden und ablegen',
    text: 'Das Abbild öffnen und ConnectionLimit in den Ordner „Programme“ ziehen. '
        + 'Ein Universal-Programm für Apple Silicon und Intel.',
  },
  ...(DOWNLOAD.notarized ? [] : [GATEKEEPER_STEP]),
  {
    title: 'Netz einstufen',
    text: 'Solange ein Netz nicht eingestuft ist, sperrt das Werkzeug bewusst nichts. '
        + 'In der Menüleiste oben rechts — oder im Terminal.',
    code: 'connlimit net set current teuer',
    codeNote: 'Oder im Terminal',
  },
]

export function Start() {
  const head = useReveal<HTMLDivElement>()
  const card = useReveal<HTMLDivElement>(60)

  return (
    <section id="loslegen">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">Loslegen</span>
          <h2>Laden, öffnen, Netz einstufen</h2>
          <p className="lead">
            Beim ersten Start ist auch das Heim-WLAN unbekannt. Dort ungefragt Dienste
            einzufrieren wäre die falsche Art Überraschung — deshalb passiert erst
            etwas, wenn du ein Netz einstufst.
          </p>
        </div>

        <div className="download reveal" ref={card}>
          <div className="download-main">
            <div>
              <span className="pill pill-green">Version {DOWNLOAD.version}</span>
              <h3 className="download-title">ConnectionLimit für macOS</h3>
              <p className="download-meta">
                {DOWNLOAD.requires} · {DOWNLOAD.architectures} · {DOWNLOAD.size}
              </p>
            </div>
            <a className="btn btn-primary btn-lg" href={DOWNLOAD.file} download>
              <span aria-hidden>↓</span> Laden ({DOWNLOAD.size})
            </a>
          </div>
          <Checksum value={DOWNLOAD.sha256} />
        </div>

        <div className="steps-grid" style={{ marginTop: 18 }}>
          {STEPS.map((step, index) => (
            <Install key={step.title} step={step} number={index + 1} delay={index * 80} />
          ))}
        </div>

        <p className="build-note">
          {DOWNLOAD.notarized
            ? 'Signiert mit Developer ID und bei Apple notarisiert. '
            : 'Nichts davon ist eine Blackbox: Das Programm ist ad hoc signiert, nicht '
              + 'notarisiert — genau deshalb der Umweg in Schritt 2. '}
          Die Kommandozeile steckt im Programm; einmal verknüpfen, dann liegt sie im
          PATH:{' '}
          <code className="mono">
            ln -s /Applications/ConnectionLimit.app/Contents/MacOS/connlimit
            {' '}~/.local/bin/connlimit
          </code>
          {GITHUB_URL && (
            <>
              {' '}Wer lieber selbst baut, findet den vollständigen Quelltext samt
              Prüfsuite auf <a href={GITHUB_URL}>GitHub</a>.
            </>
          )}
        </p>
      </div>
    </section>
  )
}

function Checksum({ value }: { value: string }) {
  const [copied, setCopied] = useState(false)
  return (
    <div className="checksum">
      <span>SHA-256</span>
      <code className="mono">{value}</code>
      <button
        onClick={async () => {
          try {
            await navigator.clipboard.writeText(value)
            setCopied(true)
            window.setTimeout(() => setCopied(false), 1600)
          } catch {
            setCopied(false)
          }
        }}
      >
        {copied ? 'kopiert' : 'kopieren'}
      </button>
    </div>
  )
}

function Install({ step, number, delay }: { step: Step; number: number; delay: number }) {
  const ref = useReveal<HTMLDivElement>(delay)
  const [copied, setCopied] = useState(false)

  const copy = async () => {
    if (!step.code) return
    try {
      await navigator.clipboard.writeText(step.code)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1600)
    } catch {
      setCopied(false)
    }
  }

  return (
    <div className="install reveal" ref={ref}>
      <div className="install-n mono">{String(number).padStart(2, '0')}</div>
      <h3>{step.title}</h3>
      <p style={{ fontSize: '0.86rem', color: 'var(--muted)', marginTop: 6 }}>{step.text}</p>
      {step.code && (
        <>
          {step.codeNote && <p className="code-note">{step.codeNote}</p>}
          <div className="code">
            <span>{step.code}</span>
            <button onClick={copy}>{copied ? 'kopiert' : 'kopieren'}</button>
          </div>
        </>
      )}
    </div>
  )
}
