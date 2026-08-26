import info from './build-info.json'

/// Adresse des Quelltexts. Ist sie leer, blendet die Seite jeden Verweis
/// darauf aus — ein toter Link wäre schlechter als gar keiner.
export const GITHUB_URL = 'https://github.com/mitsol/connectionlimit'

/// Alles, was sich mit einer neuen Fassung ändert, schreibt
/// `Tools/make-download.sh` beim Bauen des Pakets nach `build-info.json`.
///
/// Von Hand gepflegt veraltet so etwas mit dem ersten neuen Bau — und eine
/// Seite, die eine falsche Prüfsumme nennt, ist schlimmer als eine, die gar
/// keine nennt.
export const DOWNLOAD = {
  version: info.version,
  /// Das Paket liegt bei den GitHub-Releases, nicht im Repository: Sonst läge
  /// jede Fassung für immer als Vier-Megabyte-Brocken in der Historie — und
  /// die Seite ließe sich nirgends bauen, wo die Datei fehlt.
  file: GITHUB_URL
    ? `${GITHUB_URL}/releases/download/v${info.version}/${info.file}`
    : `./download/${info.file}`,
  size: info.size,
  sha256: info.sha256,
  /// Bei Apple notarisiert? Steuert, ob die Seite den Umweg über das
  /// Kontextmenü erklärt.
  notarized: info.notarized,
  requires: 'macOS 14 oder neuer',
  architectures: 'Apple Silicon und Intel',
}
