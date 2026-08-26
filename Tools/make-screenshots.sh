#!/bin/bash
# Nimmt das Fenster in jedem Bereich auf — für README und Website.
#
# Der Bereich wird über die gemerkte Auswahl (`mainTab`) gesetzt und die App
# neu gestartet; klicken kann dieses Skript nicht, und Bedienungshilfen dafür
# einzuschalten wäre eine unangemessen große Bitte an den Nutzer.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/ConnectionLimit.app"
OUT="$ROOT/web/public/screenshots"
BUNDLE_ID="at.mitsol.connectionlimit"
mkdir -p "$OUT"

# Bildschirm wach halten — ein schlafendes Display liefert schwarze Bilder.
caffeinate -u -t 240 &
CAFFEINE=$!
trap 'kill $CAFFEINE 2>/dev/null || true' EXIT
sleep 2

windowID() {
  /usr/bin/swift "$ROOT/Tools/window-id.swift" 2>/dev/null
}

# Ein Programm ohne Dock-Symbol holt sich den Fokus nicht selbst zurück;
# `open` allein reicht nicht. Über die Bedienungshilfen geht es — dafür muss
# das Terminal einmalig unter Systemeinstellungen › Datenschutz › Bedienungs-
# hilfen freigegeben sein. Ohne Freigabe wird das Fenster grau gezeichnet,
# aufgenommen wird es trotzdem.
activate() {
  osascript -e 'with timeout of 5 seconds
tell application "System Events" to tell process "ConnectionLimit" to set frontmost to true
end timeout' >/dev/null 2>&1 &
  local pid=$!
  ( sleep 8; kill $pid 2>/dev/null ) >/dev/null 2>&1 &
  wait $pid 2>/dev/null || true
}

shot() {
  local tab="$1" file="$2"
  defaults write "$BUNDLE_ID" mainTab -string "$tab"
  pkill -f "ConnectionLimit.app/Contents/MacOS/ConnectionLimit" 2>/dev/null || true
  sleep 1.5
  open "$APP" --args --window
  sleep 5

  local attempt
  for attempt in 1 2 3; do
    # Erst das Display wecken, dann die App nach vorn holen — in dieser
    # Reihenfolge: `caffeinate -u` bringt das zuletzt benutzte Programm nach
    # vorn, und ein Fenster ohne Fokus wird grau gezeichnet.
    caffeinate -u -t 2
    sleep 0.8
    activate
    sleep 1.5

    local id
    id="$(windowID)"
    if [ -n "$id" ] && screencapture -x -o -l "$id" "$OUT/$file" 2>/dev/null; then
      echo "  ✓ $file  ($tab)"
      return
    fi
  done
  echo "  ⚠ $file  ($tab) — kein Bild"
}

echo "▸ Nehme auf nach $OUT"
shot "Verbrauch"  "verbrauch.png"
shot "Protokoll"  "protokoll.png"
shot "Profile"    "profile.png"
shot "Dienste"    "dienste.png"
# Der Bereich „Netze" wird bewusst nicht aufgenommen: Er zeigt die MAC-Adresse
# des eigenen Routers. Die steht in Wardriving-Datenbanken und verrät damit
# oft die Wohnadresse — nichts, was in ein öffentliches Repository gehört.
shot "Budget"     "budget.png"

defaults write "$BUNDLE_ID" mainTab -string "Verbrauch"
echo "▸ Fertig."
