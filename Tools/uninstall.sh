#!/bin/bash
# Entfernt, was install.sh eingerichtet hat.
#
# Vor dem Entfernen werden alle Sperren aufgehoben. Eine App, die
# eingefrorene Prozesse zurücklässt, während sie sich selbst deinstalliert,
# wäre nicht zu verantworten — niemand könnte sie danach noch auftauen.
set -euo pipefail

BUNDLE_ID="at.mitsol.connectionlimit"
TARGET_APP="/Applications/ConnectionLimit.app"
AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
KEEP_DATA="${CONNLIMIT_KEEP_DATA:-1}"

if [ -x "$TARGET_APP/Contents/MacOS/connlimit" ]; then
  echo "▸ Hebe alle Sperren auf"
  "$TARGET_APP/Contents/MacOS/connlimit" unblock-all || true
fi

echo "▸ Autostart entfernen"
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
rm -f "$AGENT"

echo "▸ Programm beenden"
pkill -f "ConnectionLimit.app/Contents/MacOS/ConnectionLimit" 2>/dev/null || true
sleep 1

echo "▸ App und Befehl entfernen"
rm -rf "$TARGET_APP"
for candidate in "$HOME/.local/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
  link="$candidate/connlimit"
  if [ -L "$link" ]; then rm -f "$link"; fi
done

if [ "$KEEP_DATA" = "1" ]; then
  echo "▸ Messdaten bleiben unter ~/Library/Application Support/$BUNDLE_ID/"
  echo "  (mit CONNLIMIT_KEEP_DATA=0 werden sie mit entfernt)"
else
  rm -rf "$HOME/Library/Application Support/$BUNDLE_ID"
  echo "▸ Messdaten entfernt"
fi

echo "▸ Fertig."
