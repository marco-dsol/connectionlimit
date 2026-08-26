#!/bin/bash
# Baut aus dem SwiftPM-Executable ein lauffähiges .app-Bundle.
#
# Ohne Xcode gibt es kein App-Target, das ein Bundle erzeugt — und ohne Bundle
# gibt es keine Menüleisten-App. Deshalb wird es hier von Hand zusammengesetzt.
# Für die Weitergabe an Dritte bräuchte es zusätzlich eine Developer-ID-Signatur
# und Notarisierung; für den eigenen Mac genügt eine Ad-hoc-Signatur.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/ConnectionLimit.app"
BUNDLE_ID="at.mitsol.connectionlimit"
VERSION="0.1.0"

echo "▸ Zeichne das Symbol…"
( cd "$ROOT" && swift Tools/make-icon.swift >/dev/null )
iconutil -c icns "$ROOT/dist/AppIcon.iconset" -o "$ROOT/dist/AppIcon.icns"

echo "▸ Baue ($CONFIG)…"
swift build -c "$CONFIG" --product ConnectionLimitApp
swift build -c "$CONFIG" --product connlimit

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "▸ Setze Bundle zusammen…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/ConnectionLimitApp" "$APP/Contents/MacOS/ConnectionLimit"
cp "$BIN_DIR/connlimit" "$APP/Contents/MacOS/connlimit"
cp "$ROOT/dist/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ConnectionLimit</string>
    <key>CFBundleDisplayName</key><string>ConnectionLimit</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleExecutable</key><string>ConnectionLimit</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <!-- Menüleisten-Programm: kein Dock-Symbol, kein Menüband. -->
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>ConnectionLimit</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Mit Developer-ID-Zertifikat richtig signieren, sonst ad hoc. Ohne diese
# Weiche würde jeder Bau die Signatur des Download-Pakets wieder überschreiben.
IDENTITY="${CONNLIMIT_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep 'Developer ID Application' | head -1 \
    | sed 's/.*"\(.*\)".*/\1/')" || true
fi

if [ -n "$IDENTITY" ]; then
  echo "▸ Signiere mit: $IDENTITY"
  # Von innen nach außen; `--deep` rät Apple ausdrücklich ab.
  codesign --force --options runtime --timestamp \
           --sign "$IDENTITY" "$APP/Contents/MacOS/connlimit"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
  echo "▸ Signiere ad hoc…"
  codesign --force --deep --sign - "$APP"
fi

echo "▸ Fertig: $APP"
echo
echo "  Starten:      open $APP"
echo "  CLI:          $APP/Contents/MacOS/connlimit"
echo "  Installieren: cp -R $APP /Applications/"
