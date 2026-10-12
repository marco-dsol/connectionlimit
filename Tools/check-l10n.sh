#!/bin/bash
# Prüft die englische Übersetzung gegen den Quelltext:
#
#   1. Jeder Text in `L("…")` und jede Katalognotiz hat einen Eintrag.
#   2. Kein Schlüssel steht doppelt in der Tabelle — ein doppelter Schlüssel
#      in einem Swift-Dictionary-Literal bringt das Programm beim Start zum
#      Absturz, und zwar erst zur Laufzeit.
#   3. Kein Eintrag ist verwaist (steht in der Tabelle, wird aber nirgends
#      mehr benutzt) — nur als Hinweis, kein Fehler.
#
# Die Platzhalter prüft die Prüfsuite (`swift run connlimit-selftest`).
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'EOF'
import glob, re, sys

literal = r'"((?:[^"\\]|\\.)*)"'
used = set()
for path in glob.glob('Sources/**/*.swift', recursive=True):
    if 'selftest' in path or path.endswith('Strings+en.swift'):
        continue
    text = open(path, encoding='utf-8').read()
    used.update(re.findall(r'\bL\(\s*' + literal, text))

catalog = open('Sources/ConnLimitCore/Catalog/BuiltinCatalog.swift', encoding='utf-8').read()
notes = set(re.findall(r'note:\s*' + literal, catalog))
used |= notes

# Schlüssel, die nicht als Literal in `L(…)` stehen: Bereichs- und
# Filternamen (`L(rawValue)`) und Bestandteile automatischer Netznamen.
used |= {"Verbrauch", "Protokoll", "Profile", "Dienste", "Netze", "Budget",
         "Alle", "Aktiv", "Gesperrt", "Durchbrüche",
         "iPhone-Hotspot", "WLAN", "Kabel", "Netz", "Offline"}

table = open('Sources/ConnLimitCore/L10n/Strings+en.swift', encoding='utf-8').read()
keys = re.findall(r'^\s*' + literal + r'\s*:', table, re.M)

errors = 0
seen = set()
for key in keys:
    if key in seen:
        print(f"doppelt: {key}")
        errors += 1
    seen.add(key)

for key in sorted(used - seen):
    print(f"fehlt:   {key}")
    errors += 1

# Katalognamen ohne Eintrag sind Markennamen und bleiben, wie sie sind.
names = set(re.findall(r'svc\("[^"]+",\s*' + literal, catalog))
for key in sorted(seen - used - names):
    print(f"verwaist (Hinweis): {key}")

if errors:
    print(f"\n{errors} Problem(e) in der Übersetzung.")
    sys.exit(1)
print(f"Übersetzung vollständig: {len(seen)} Einträge.")
EOF
