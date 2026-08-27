#!/bin/bash
# Installiert die fertige Fassung von GitHub — ohne Quelltext, ohne Xcode,
# ohne Swift. Für den zweiten Mac gedacht:
#
#   curl -fsSL https://raw.githubusercontent.com/mitsol/connectionlimit/main/Tools/install-release.sh | bash
#
# Holt das neueste Release, legt die App nach /Applications, verknüpft den
# Befehl `connlimit` und richtet den Autostart ein. Rückweg: uninstall.sh
# aus demselben Ordner, oder von Hand — es sind genau drei Dinge.
set -euo pipefail

REPO="mitsol/connectionlimit"
BUNDLE_ID="at.mitsol.connectionlimit"
APP="/Applications/ConnectionLimit.app"
AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
NO_AGENT="${CONNLIMIT_NO_AUTOSTART:-}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; [ -n "${MOUNTED:-}" ] && hdiutil detach "$MOUNTED" -quiet 2>/dev/null || true' EXIT

# macOS 14 ist die Untergrenze — darunter fehlen benutzte Schnittstellen.
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MAJOR" -lt 14 ]; then
  echo "▸ Dieses Programm braucht macOS 14 oder neuer (gefunden: $(sw_vers -productVersion))." >&2
  exit 1
fi

echo "▸ Suche die neueste Fassung…"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"browser_download_url"' | grep '\.dmg"' | head -1 \
  | sed 's/.*"\(https[^"]*\)".*/\1/')"
[ -n "$URL" ] || { echo "▸ Kein DMG im neuesten Release gefunden." >&2; exit 1; }
echo "  $URL"

echo "▸ Lade…"
curl -fL# -o "$TMP/ConnectionLimit.dmg" "$URL"

echo "▸ Hänge das Abbild ein…"
# Kein -quiet: Das unterdrückt genau die Zeile mit dem Einhängepunkt.
MOUNTED="$(hdiutil attach -nobrowse "$TMP/ConnectionLimit.dmg" \
  | grep -o '/Volumes/.*' | tail -1)"
[ -d "$MOUNTED/ConnectionLimit.app" ] || { echo "▸ Im Abbild steckt keine App." >&2; exit 1; }

# Vor dem Ersetzen beenden, sonst bleibt die alte Fassung im Speicher.
if [ -f "$AGENT" ]; then launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true; fi
pkill -f "ConnectionLimit.app/Contents/MacOS/ConnectionLimit" 2>/dev/null || true
sleep 1

echo "▸ Installiere nach $APP"
rm -rf "$APP"
cp -R "$MOUNTED/ConnectionLimit.app" /Applications/
hdiutil detach "$MOUNTED" -quiet
MOUNTED=""

# Zielordner für den Befehl: der erste beschreibbare aus dem PATH.
BIN_DIR=""
for candidate in "$HOME/.local/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
  case ":$PATH:" in *":$candidate:"*) ;; *) continue ;; esac
  if [ -d "$candidate" ] && [ -w "$candidate" ]; then BIN_DIR="$candidate"; break; fi
done
[ -n "$BIN_DIR" ] || { BIN_DIR="$HOME/.local/bin"; mkdir -p "$BIN_DIR"; }
ln -sf "$APP/Contents/MacOS/connlimit" "$BIN_DIR/connlimit"
echo "▸ Befehl verknüpft: $BIN_DIR/connlimit"

if [ -n "$NO_AGENT" ]; then
  echo "▸ Autostart übersprungen (CONNLIMIT_NO_AUTOSTART gesetzt)"
else
  mkdir -p "$(dirname "$AGENT")"
  cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array><string>$APP/Contents/MacOS/ConnectionLimit</string></array>
    <key>RunAtLoad</key><true/>
    <!-- Bewusst kein KeepAlive: „Beenden“ im Menü muss beenden heißen. -->
    <key>KeepAlive</key><false/>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST
  launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null \
    || launchctl load "$AGENT" 2>/dev/null || true
  echo "▸ Autostart eingerichtet"
fi

sleep 1
pgrep -f "ConnectionLimit.app/Contents/MacOS/ConnectionLimit" >/dev/null || open "$APP"

echo
echo "▸ Fertig. Das Symbol sitzt in der Menüleiste, kein Dock-Symbol."
echo
echo "  Nächster Schritt — solange ein Netz nicht eingestuft ist, wird nichts gesperrt:"
echo "      connlimit net set current frei      # zuhause"
echo "      connlimit net set current teuer     # Hotspot"
