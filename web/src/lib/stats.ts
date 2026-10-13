/// Besucherstatistik mit Umami auf dem eigenen Server — wie auf dsol.at und
/// bei Schneezauber: nur mit Zustimmung, ohne Cookies. Ohne Zustimmung wird
/// das Skript gar nicht erst geladen.
///
/// Ist `websiteId` leer, gibt es weder Banner noch Skript: Um Zustimmung für
/// etwas zu bitten, das gar nicht zählt, wäre unehrlich.
export const UMAMI = {
  script: 'https://umami.dsol.at/script.js',
  websiteId: '',
  /// Nur auf der echten Adresse zählen, nicht beim Entwickeln oder in einer
  /// Vorschau.
  domains: 'connectionlimit.dsol.at',
}

export type Consent = 'granted' | 'denied'

const STORAGE_KEY = 'cl-stats'
/// Umamis eigener Schalter: Steht er im Speicher, sendet das Skript nichts —
/// auch dann nicht, wenn es aus der letzten Sitzung noch geladen ist.
const UMAMI_OFF = 'umami.disabled'

export const statsEnabled = UMAMI.websiteId !== ''

export function storedConsent(): Consent | null {
  try {
    const value = window.localStorage.getItem(STORAGE_KEY)
    return value === 'granted' || value === 'denied' ? value : null
  } catch {
    return null
  }
}

export function saveConsent(consent: Consent) {
  try {
    window.localStorage.setItem(STORAGE_KEY, consent)
  } catch {
    /* Speicher gesperrt (privates Fenster) — die Wahl gilt dann nur jetzt */
  }
  applyConsent(consent)
}

/// Lädt das Skript nach einer Zustimmung, schaltet es nach einem Widerruf
/// stumm. Einmal geladen, lässt es sich nicht mehr entladen — dafür gibt es
/// `umami.disabled`.
export function applyConsent(consent: Consent | null) {
  if (!statsEnabled) return
  const granted = consent === 'granted'
  try {
    if (granted) window.localStorage.removeItem(UMAMI_OFF)
    else window.localStorage.setItem(UMAMI_OFF, '1')
  } catch {
    /* siehe oben */
  }
  if (!granted || document.getElementById('umami-script')) return
  const script = document.createElement('script')
  script.id = 'umami-script'
  script.defer = true
  script.src = UMAMI.script
  script.dataset.websiteId = UMAMI.websiteId
  script.dataset.domains = UMAMI.domains
  document.head.appendChild(script)
}
