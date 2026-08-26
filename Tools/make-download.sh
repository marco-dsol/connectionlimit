#!/bin/bash
# Baut das Paket, das auf der Website zum Laden angeboten wird:
# ein Universal-Programm (Apple Silicon + Intel) in einem DMG.
#
# Universal geht hier nur von Hand: `swift build --arch arm64 --arch x86_64`
# verlangt ein vollständiges Xcode. Übersetzen für die jeweils andere
# Architektur geht aber auch mit den Command Line Tools — danach fügt `lipo`
# die beiden Fassungen zusammen.
#
# Signieren und notarisieren, wenn die Voraussetzungen da sind:
#
#   CONNLIMIT_SIGN_IDENTITY   Name des Developer-ID-Zertifikats. Ohne Angabe
#                             wird im Schlüsselbund danach gesucht.
#   CONNLIMIT_NOTARY_PROFILE  Name des Schlüsselbund-Eintrags aus
#                             `xcrun notarytool store-credentials`.
#
# Fehlt eines von beiden, wird ad hoc signiert wie bisher — der Bau läuft also
# auch auf einem Rechner ohne Apple-Konto durch. Was fehlt, sagt das Skript.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/ConnectionLimit.app"
VERSION="0.1.0"
OUT_DIR="$ROOT/web/public/download"
DMG="$OUT_DIR/ConnectionLimit-$VERSION.dmg"
STAGE="$ROOT/dist/dmg-stage"
NOTARY_PROFILE="${CONNLIMIT_NOTARY_PROFILE:-}"

# Zertifikat suchen, falls nicht vorgegeben.
IDENTITY="${CONNLIMIT_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' | head -1 \
    | sed 's/.*"\(.*\)".*/\1/')" || true
fi

"$ROOT/Tools/make-app-bundle.sh" release | sed 's/^/  /'

echo "▸ Übersetze zusätzlich für Intel…"
# Eigener Arbeitsordner: Beide Architekturen im selben `.build` bringen die
# Baubeschreibung durcheinander, und der nächste native Bau schlägt fehl.
SCRATCH="$ROOT/.build-x86"
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "$SCRATCH" \
            --product ConnectionLimitApp >/dev/null
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path "$SCRATCH" \
            --product connlimit >/dev/null
INTEL_BIN="$SCRATCH/x86_64-apple-macosx/release"

echo "▸ Füge die Architekturen zusammen…"
lipo -create "$APP/Contents/MacOS/ConnectionLimit" "$INTEL_BIN/ConnectionLimitApp" \
     -output "$APP/Contents/MacOS/ConnectionLimit.universal"
mv "$APP/Contents/MacOS/ConnectionLimit.universal" "$APP/Contents/MacOS/ConnectionLimit"
lipo -create "$APP/Contents/MacOS/connlimit" "$INTEL_BIN/connlimit" \
     -output "$APP/Contents/MacOS/connlimit.universal"
mv "$APP/Contents/MacOS/connlimit.universal" "$APP/Contents/MacOS/connlimit"
lipo -archs "$APP/Contents/MacOS/ConnectionLimit" | sed 's/^/  Architekturen: /'

NOTARIZED=0

if [ -n "$IDENTITY" ]; then
  echo "▸ Signiere mit: $IDENTITY"
  # Von innen nach außen. `--deep` rät Apple ausdrücklich ab: Es signiert
  # Eingebettetes mit denselben Angaben wie die Hülle, was bei mehreren
  # Programmen im Bundle das Falsche ist.
  codesign --force --options runtime --timestamp \
           --sign "$IDENTITY" "$APP/Contents/MacOS/connlimit"
  codesign --force --options runtime --timestamp \
           --sign "$IDENTITY" "$APP"
  codesign --verify --strict --verbose=1 "$APP" 2>&1 | sed 's/^/  /'
else
  echo "▸ Kein Developer-ID-Zertifikat gefunden — signiere ad hoc"
  codesign --force --deep --sign - "$APP" 2>/dev/null
fi

if [ -n "$IDENTITY" ] && [ -n "$NOTARY_PROFILE" ]; then
  echo "▸ Reiche das Programm zur Notarisierung ein (das dauert ein paar Minuten)…"
  ZIP="$ROOT/dist/ConnectionLimit-notarize.zip"
  rm -f "$ZIP"
  # `ditto` statt `zip`: Nur so bleiben Symlinks und erweiterte Attribute
  # erhalten, und nur so erkennt der Dienst das Bundle als solches.
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait \
    | sed 's/^/  /'
  rm -f "$ZIP"

  echo "▸ Hefte das Ticket an das Programm"
  xcrun stapler staple "$APP" | sed 's/^/  /'
  NOTARIZED=1
fi

echo "▸ Baue das DMG…"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE" "$OUT_DIR"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Programme"
hdiutil create -volname "ConnectionLimit $VERSION" -srcfolder "$STAGE" \
               -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"

if [ "$NOTARIZED" = "1" ]; then
  # Das Abbild wird eigens signiert und notarisiert. Ohne das prüft macOS beim
  # Öffnen online nach — und ohne Netz gäbe es dann eine Warnung, obwohl alles
  # in Ordnung ist.
  echo "▸ Signiere und notarisiere das Abbild…"
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait \
    | sed 's/^/  /'
  xcrun stapler staple "$DMG" | sed 's/^/  /'
fi

BYTES="$(stat -f%z "$DMG")"
SIZE="$(awk -v b="$BYTES" 'BEGIN { printf "%.1f MB", b / 1000000 }' | sed 's/\./,/')"
SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
echo "$SHA  ConnectionLimit-$VERSION.dmg" > "$OUT_DIR/ConnectionLimit-$VERSION.dmg.sha256"

# Die Website liest diese Datei. Von Hand gepflegte Angaben veralten mit dem
# ersten neuen Bau, und eine Seite, die eine falsche Prüfsumme nennt, ist
# schlimmer als eine, die gar keine nennt.
NOTARIZED_JSON=false
[ "$NOTARIZED" = "1" ] && NOTARIZED_JSON=true
cat > "$ROOT/web/src/lib/build-info.json" <<JSON
{
  "version": "$VERSION",
  "file": "ConnectionLimit-$VERSION.dmg",
  "size": "$SIZE",
  "bytes": $BYTES,
  "sha256": "$SHA",
  "notarized": $NOTARIZED_JSON
}
JSON

echo
echo "▸ Fertig: $DMG  ($SIZE)"
echo "  SHA-256: $SHA"
echo "  Angaben für die Website geschrieben: web/src/lib/build-info.json"
spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1 | sed 's/^/  Gatekeeper: /' || true

echo
if [ "$NOTARIZED" = "1" ]; then
  echo "  Notarisiert — auf der Website entfällt damit der Umweg über das Kontextmenü."
else
  echo "    notarized: false"
  echo
  echo "  Nicht notarisiert. Es fehlt:"
  [ -z "$IDENTITY" ] && cat <<'HINT'
    · ein Developer-ID-Zertifikat. Im Developer-Portal unter
      Certificates › Developer ID Application erzeugen und in den
      Schlüsselbund laden. Prüfen mit:
          security find-identity -v -p codesigning
HINT
  [ -z "$NOTARY_PROFILE" ] && cat <<'HINT'
    · die Zugangsdaten für notarytool. Einmalig anlegen (fragt das
      app-spezifische Passwort interaktiv ab, es landet dann im
      Schlüsselbund, nicht in der Verlaufsdatei der Shell):
          xcrun notarytool store-credentials connectionlimit \
            --apple-id <deine-apple-id> --team-id <TEAM-ID>
      Danach:
          CONNLIMIT_NOTARY_PROFILE=connectionlimit ./Tools/make-download.sh
HINT
fi
