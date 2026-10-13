import { useEffect, useState } from 'react'
import { useLang } from '../i18n'
import { clearHash } from '../lib/hash'
import { applyConsent, saveConsent, statsEnabled, storedConsent, type Consent as Choice } from '../lib/stats'

/// Kein Fenster, das die Seite sperrt: Das Banner steht unten, und wer es
/// übergeht, wird einfach nicht gezählt. Wieder öffnen lässt es sich über
/// `#statistik` — den Link im Fuß und in der Datenschutzerklärung.
const HASH = '#statistik'

export function Consent() {
  const { t } = useLang()
  const [open, setOpen] = useState(
    () => statsEnabled && (storedConsent() === null || window.location.hash === HASH),
  )

  // Eine frühere Zustimmung gilt ab dem ersten Bild.
  useEffect(() => applyConsent(storedConsent()), [])

  useEffect(() => {
    if (!statsEnabled) return
    const onHash = () => window.location.hash === HASH && setOpen(true)
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  if (!open) return null

  const choose = (choice: Choice) => {
    saveConsent(choice)
    setOpen(false)
    if (window.location.hash === HASH) clearHash()
  }

  return (
    <section className="consent" aria-labelledby="consent-title">
      <div>
        <strong id="consent-title">{t.stats.title}</strong>
        <p>{t.stats.text} <a href="#datenschutz">{t.stats.privacy}</a></p>
      </div>
      <div className="consent-actions">
        <button type="button" className="btn btn-ghost btn-sm" onClick={() => choose('denied')}>{t.stats.deny}</button>
        <button type="button" className="btn btn-primary btn-sm" onClick={() => choose('granted')}>{t.stats.accept}</button>
      </div>
    </section>
  )
}
