#!/bin/bash
# Baut das Werkzeug und richtet es auf diesem Mac ein:
#
#   1. die App nach /Applications
#   2. den Befehl `connlimit` in einen Ordner, der im PATH liegt
#   3. einen LaunchAgent, damit beim Anmelden gemessen wird
#
# Punkt 3 ist kein Beiwerk: Gemessen wird nur, solange das Programm läuft.
# Ohne Autostart fehlt jedes Mal die Zeit zwischen Anmelden und erstem Klick —
# und genau dann laden Updates und Sync-Clients am liebsten.
#
# Rückweg: ./Tools/uninstall.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ConnectionLimit.app"
TARGET_APP="/Applications/$APP_NAME"
BUNDLE_ID="at.mitsol.connectionlimit"
AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
NO_AGENT="${CONNLIMIT_NO_AUTOSTART:-}"

# Ziel für den Befehl: der erste beschreibbare Ordner aus dem PATH, der
# üblicherweise dafür gedacht ist. Kein sudo, kein /usr/local/bin auf gut Glück.
BIN_DIR=""
for candidate in "$HOME/.local/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
  case ":$PATH:" in *":$candidate:"*) ;; *) continue ;; esac
  if [ -d "$candidate" ] && [ -w "$candidate" ]; then BIN_DIR="$candidate"; break; fi
done
if [ -z "$BIN_DIR" ]; then
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
fi

echo "▸ Baue…"
"$ROOT/Tools/make-app-bundle.sh" release | sed 's/^/  /'

echo "▸ Beende laufende Fassungen…"
# Erst der LaunchAgent, dann der Prozess — sonst startet er sofort wieder.
if [ -f "$AGENT" ]; then launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true; fi
pkill -f "$APP_NAME/Contents/MacOS/ConnectionLimit" 2>/dev/null || true
sleep 1

echo "▸ Installiere nach $TARGET_APP"
rm -rf "$TARGET_APP"
cp -R "$ROOT/dist/$APP_NAME" "$TARGET_APP"

echo "▸ Verknüpfe $BIN_DIR/connlimit"
ln -sf "$TARGET_APP/Contents/MacOS/connlimit" "$BIN_DIR/connlimit"

if [ -n "$NO_AGENT" ]; then
  echo "▸ Autostart übersprungen (CONNLIMIT_NO_AUTOSTART gesetzt)"
else
  echo "▸ Richte Autostart ein"
  mkdir -p "$(dirname "$AGENT")"
  cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_APP/Contents/MacOS/ConnectionLimit</string>
    </array>
    <key>RunAtLoad</key><true/>
    <!-- Bewusst kein KeepAlive: „Beenden“ im Menü muss beenden heißen.
         Ein Programm, das sich selbst wieder startet, kann man nicht loswerden. -->
    <key>KeepAlive</key><false/>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST
  launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null \
    || launchctl load "$AGENT" 2>/dev/null || true
fi

# Läuft der Dienst nicht schon durch den LaunchAgent, jetzt starten.
sleep 1
if ! pgrep -f "$APP_NAME/Contents/MacOS/ConnectionLimit" >/dev/null; then
  open "$TARGET_APP"
  sleep 2
fi

echo
echo "▸ Fertig."
echo "  App:      $TARGET_APP  (Symbol in der Menüleiste, kein Dock-Symbol)"
echo "  Befehl:   $BIN_DIR/connlimit  →  'connlimit status'"
[ -z "$NO_AGENT" ] && echo "  Autostart: $AGENT"
echo "  Daten:    ~/Library/Application Support/$BUNDLE_ID/"
echo
echo "  Nächster Schritt — solange ein Netz nicht eingestuft ist, wird nichts gesperrt:"
echo "      connlimit net set current teuer"
echo
echo "  Alles rückgängig: $ROOT/Tools/uninstall.sh"
