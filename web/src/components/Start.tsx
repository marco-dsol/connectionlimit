import { useState } from 'react'
import { useReveal } from '../hooks/useReveal'
import { DOWNLOAD, GITHUB_URL, downloadSize } from '../lib/download'
import { useLang } from '../i18n'
import type { InstallStep } from '../i18n/de'

export function Start() {
  const { t } = useLang()
  const s = t.start
  const size = downloadSize(t.decimal)
  // Ist das Paket notarisiert, fällt der Umweg über das Kontextmenü weg — und
  // mit ihm der ganze Schritt. Ein Hinweis, der nicht mehr stimmt, ist
  // schlimmer als keiner.
  const steps: InstallStep[] = [
    s.steps.get,
    ...(DOWNLOAD.notarized ? [] : [s.steps.gatekeeper]),
    s.steps.classify,
  ]
  const head = useReveal<HTMLDivElement>()
  const card = useReveal<HTMLDivElement>(60)

  return (
    <section id="loslegen">
      <div className="wrap">
        <div className="section-head reveal" ref={head}>
          <span className="eyebrow">{s.eyebrow}</span>
          <h2>{s.title}</h2>
          <p className="lead">{s.lead}</p>
        </div>

        <div className="download reveal" ref={card}>
          <div className="download-main">
            <div>
              <span className="pill pill-green">{s.version} {DOWNLOAD.version}</span>
              <h3 className="download-title">{s.product}</h3>
              <p className="download-meta">
                {t.download.requires} · {t.download.architectures} · {size}
              </p>
            </div>
            <a className="btn btn-primary btn-lg" href={DOWNLOAD.file} download>
              <span aria-hidden>↓</span> {s.download(size)}
            </a>
          </div>
          <Checksum value={DOWNLOAD.sha256} copy={s.copy} copied={s.copied} />
        </div>

        <div className="steps-grid" style={{ marginTop: 18, ['--steps' as string]: steps.length }}>
          {steps.map((step, index) => (
            <Install key={step.title} step={step} number={index + 1} delay={index * 80}
                     copy={s.copy} copied={s.copied} />
          ))}
        </div>

        <p className="build-note">
          {DOWNLOAD.notarized ? s.notarized : s.adhoc}
          {s.cli}{' '}
          <code className="mono">
            ln -s /Applications/ConnectionLimit.app/Contents/MacOS/connlimit
            {' '}~/.local/bin/connlimit
          </code>
          {GITHUB_URL && (
            <>
              {' '}{s.sourceBefore} <a href={GITHUB_URL}>GitHub</a>{s.sourceAfter}
            </>
          )}
        </p>
      </div>
    </section>
  )
}

interface CopyLabels {
  copy: string
  copied: string
}

function Checksum({ value, copy, copied: copiedLabel }: { value: string } & CopyLabels) {
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
        {copied ? copiedLabel : copy}
      </button>
    </div>
  )
}

function Install({
  step,
  number,
  delay,
  copy: copyLabel,
  copied: copiedLabel,
}: { step: InstallStep; number: number; delay: number } & CopyLabels) {
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
            <button onClick={copy}>{copied ? copiedLabel : copyLabel}</button>
          </div>
        </>
      )}
    </div>
  )
}
