/// Fenster und Banner hängen am Anker der Adresse (`#impressum`,
/// `#statistik`). Beim Schließen muss er weg, sonst öffnet ein zweiter Klick
/// auf denselben Link nichts: Die Adresse hätte sich nicht geändert.
/// Ersetzt statt neu gesetzt — kein Eintrag im Verlauf.
export function clearHash() {
  if (!window.location.hash) return
  try {
    const url = new URL(window.location.href)
    url.hash = ''
    window.history.replaceState(window.history.state, '', url)
  } catch {
    /* Adresse lässt sich nicht ändern (file://) — geschlossen ist trotzdem */
  }
}
