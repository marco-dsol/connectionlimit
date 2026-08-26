import info from './build-info.json'

/// Alles, was sich mit einer neuen Fassung ändert, schreibt
/// `Tools/make-download.sh` beim Bauen des Pakets nach `build-info.json`.
///
/// Von Hand gepflegt veraltet so etwas mit dem ersten neuen Bau — und eine
/// Seite, die eine falsche Prüfsumme nennt, ist schlimmer als eine, die gar
/// keine nennt.
export const DOWNLOAD = {
  version: info.version,
  file: `./download/${info.file}`,
  size: info.size,
  sha256: info.sha256,
  /// Bei Apple notarisiert? Steuert, ob die Seite den Umweg über das
  /// Kontextmenü erklärt.
  notarized: info.notarized,
  requires: 'macOS 14 oder neuer',
  architectures: 'Apple Silicon und Intel',
}

/// Adresse des Quelltexts. Solange sie leer ist, wird kein Verweis angezeigt —
/// ein toter Link wäre schlechter als gar keiner.
export const GITHUB_URL = ''
