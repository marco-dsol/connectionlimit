import { useCallback, useEffect, useState, type MouseEvent } from 'react'
import { Modal } from './Modal'
import { useLang } from '../i18n'

/// Impressum, Haftungsausschluss und Datenschutz in einem Fenster, erreichbar
/// über den Anker in der Adresse (`#impressum`, `#haftung`, `#datenschutz`).
/// So lässt sich jeder Teil direkt verlinken, ohne dass die Seite dafür eigene
/// Unterseiten bräuchte — und der Zurück-Knopf schließt das Fenster wieder.

export const LEGAL_PARTS = ['impressum', 'haftung', 'datenschutz'] as const
export type LegalPart = (typeof LEGAL_PARTS)[number]

function partFromHash(): LegalPart | null {
  const id = window.location.hash.slice(1)
  return (LEGAL_PARTS as readonly string[]).includes(id) ? (id as LegalPart) : null
}

export function Legal() {
  const { t } = useLang()
  const [part, setPart] = useState<LegalPart | null>(partFromHash)

  useEffect(() => {
    const onHash = () => setPart(partFromHash())
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  // Läuft nach dem Effekt des Fensters (Kinder zuerst) — es ist also schon
  // offen, wenn hier zum Abschnitt gesprungen wird.
  useEffect(() => {
    if (part) document.getElementById(`legal-${part}`)?.scrollIntoView({ block: 'start' })
  }, [part])

  // Den Anker beim Schließen entfernen, sonst öffnet ein zweiter Klick auf
  // denselben Link nichts: Die Adresse hätte sich nicht geändert.
  const close = useCallback(() => {
    setPart(null)
    if (!partFromHash()) return
    try {
      const url = new URL(window.location.href)
      url.hash = ''
      window.history.replaceState(window.history.state, '', url)
    } catch {
      /* Adresse lässt sich nicht ändern (file://) — das Fenster ist trotzdem zu */
    }
  }, [])

  // Innerhalb des Fensters springen, ohne für jeden Sprung einen Eintrag im
  // Verlauf anzulegen.
  const jump = (event: MouseEvent<HTMLAnchorElement>, next: LegalPart) => {
    event.preventDefault()
    window.history.replaceState(window.history.state, '', `#${next}`)
    setPart(next)
    document.getElementById(`legal-${next}`)?.scrollIntoView({ block: 'start', behavior: 'smooth' })
  }

  return (
    <Modal open={part !== null} onClose={close} label={t.legal.title} closeLabel={t.legal.close} className="modal-legal">
      <header className="legal-head">
        <span className="eyebrow">{t.legal.title}</span>
        <nav className="legal-tabs">
          {LEGAL_PARTS.map((id) => (
            <a key={id} href={`#${id}`} className={id === part ? 'on' : ''} onClick={(event) => jump(event, id)}>
              {t.legal.links[id]}
            </a>
          ))}
        </nav>
      </header>
      <div className="legal-body">
        {LEGAL_PARTS.map((id) => (
          <div key={id} id={`legal-${id}`} className="legal-part">
            <h2>{t.legal.links[id]}</h2>
            {t.legal[id]}
          </div>
        ))}
        <p className="legal-updated">{t.legal.updated}</p>
      </div>
    </Modal>
  )
}
