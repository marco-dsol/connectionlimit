# ConnectionLimit

Sehen, wer auf dem Mac Datenvolumen verbraucht — und es gezielt abdrehen.
Gebaut für die Situation, in der Volumen knapp ist: Hotspot, Roaming, Hotel-Tarif.

macOS zeigt keinen Verbrauch pro App und hat keinen Low-Data-Modus wie iOS.
Dieses Werkzeug schließt beide Lücken, soweit das ohne Apple-Sonderrechte geht —
und sagt klar, wo die Grenze verläuft.

![Das Fenster](web/public/screenshots/verbrauch.png)

```
$ connlimit tracked

Getrackte Dienste  ·  seit 25.08. 17:01  ·  Netz: iPhone von Marco [teuer]

  DIENST                KLASSE          GESAMT     HEUTE  ZULETZT   VERLAUF 24 h
● Google Chrome         Browser       412.7 MB  26.4 MB  gerade    ▁▂▃▅█▆▃▂▁▁▂▃
● Microsoft Outlook     E-Mail        119.3 MB  12.1 MB  gerade    ▂▃▂▁▁▂▅▃▂▁▁▁
⚠ OneDrive              Cloud-Sync     64.0 MB   1.4 MB  gerade    ▁▁▁▂▁▁▁▂▁▁▁▁
  ↳ 3× trotz Sperre aktiv · 1.4 MB · zuletzt 12:04
🔒 iCloud Fotos         Cloud-Sync    180.2 MB       —  vor 8 min  ▃▅▂▁▁·······
  macOS Update          Updates        29.0 MB       —  vor 39 min ▁▁·········
```

## Die Idee

**Nicht der Nutzer erklärt der App, dass Urlaub ist — das Netz sagt es.**

Jedes Netz wird an der MAC-Adresse seines Routers wiedererkannt (dafür braucht
es keine Ortungsdienste, anders als beim Auslesen der SSID) und einmalig als
*frei*, *teuer* oder *begrenzt* eingestuft. Am iPhone-Hotspot greift dann
automatisch der Urlaubsmodus, im Heim-WLAN fällt er von selbst wieder weg.
Genau dort passieren sonst die teuren Fehler: das Einschalten bei Ankunft
vergessen, das Ausschalten bei Rückkehr auch.

Vier Eskalationsstufen sperren nicht einzelne Apps, sondern **Klassen** — so
greifen sie auch für Dienste, die es beim Anlegen des Profils noch nicht gab:

| Stufe | sperrt ab Werk |
|---|---|
| **Aus** | nichts |
| **Sparsam** | Updates, Backups, Telemetrie, Medien — kostet keinen Komfort |
| **Urlaubsmodus** | zusätzlich Cloud-Sync (iCloud, OneDrive, Dropbox, Nextcloud) |
| **Notfall** | zusätzlich E-Mail und Browser |

Welche Klassen eine Stufe sperrt, ist **einstellbar** — im Bereich *Profile*
oder mit `connlimit profile edit`. Die Tabelle oben ist die Voreinstellung,
kein Gesetz. Nur zwei Dinge sind nicht verhandelbar: „Aus“ sperrt nichts, und
die Klasse `essential` (VPN, DNS, Push, das Werkzeug selbst) ist hart gegen
jede Sperre geschützt — auch gegen die eigene Automatik.

## Die Liste bleibt stehen

Wer einmal Daten gebraucht hat, bleibt in der Liste — bis du zurücksetzt.

Das klingt nach einer Kleinigkeit, ist aber der Unterschied zwischen „was läuft
gerade?“ und „wer kostet mich Geld?“. Ein Sync-Client, der alle zwanzig Minuten
für zehn Sekunden 40 MB hochlädt, ist in einer Momentaufnahme fast nie zu
sehen — und genau ihn will man sperren. Deshalb:

- **Dauerbeobachtung** — jeder je gesehene Dienst steht in der Liste, mit
  Gesamtmenge, Tagesmenge und dem Zeitpunkt der letzten Aktivität. Gerade
  aktive stehen oben und sind **grün**.
- **Mengenverlauf** — Stunden- und Tagesfenster je Dienst. Stille Fenster
  stehen als Null da, statt zu fehlen: Sonst sähe Ruhe aus wie schwacher
  Verkehr.
- **Protokoll** — wann gesperrt, wann freigegeben, und wann trotz gesetzter
  Sperre Daten geflossen sind. Mit Beginn, Ende und Menge.

Der letzte Punkt ist der wichtigste. Ob hinter durchgekommenen Bytes ein echter
Verbindungsversuch steckt, lässt sich ohne Netzwerkfilter nicht sagen — messbar
ist, dass Bytes gezählt wurden, während die Sperre stand. Genau das wird
festgehalten, nicht mehr. Eine Sperre, durch die etwas durchkommt, ist
schlimmer als keine, weil man sich auf sie verlässt.

Farben bedeuten überall dasselbe, in Fenster, Menü und Terminal:

| | |
|---|---|
| **grün** | bewegt gerade Daten |
| **rot** | gesperrt |
| **orange** | gesperrt, und trotzdem fließt etwas |
| **grau** | bekannt, aber still |

## Bauen

Voraussetzung: macOS 14+, Swift 6. Xcode wird **nicht** gebraucht.

```bash
swift build -c release              # CLI
./Tools/make-app-bundle.sh          # Menüleisten-App nach dist/
swift run connlimit-selftest        # Prüfsuite (129 Prüfungen)
```

`Tools/make-app-bundle.sh` setzt das `.app`-Bundle von Hand zusammen, zeichnet
das Symbol (`Tools/make-icon.swift`) und signiert ad hoc — ohne Xcode gibt es
kein App-Target, das das übernimmt.

## Installieren

```bash
./Tools/install.sh
```

Baut, legt die App nach `/Applications`, verknüpft `connlimit` in den ersten
beschreibbaren PATH-Ordner (`~/.local/bin`, sonst Homebrew) und richtet einen
LaunchAgent ein. Kein `sudo`.

Der Autostart ist kein Beiwerk: **Gemessen wird nur, solange das Programm
läuft.** Ohne ihn fehlt jedes Mal die Zeit zwischen Anmelden und erstem Klick —
und genau dann laden Updates und Sync-Clients am liebsten. Wer ihn nicht will:
`CONNLIMIT_NO_AUTOSTART=1 ./Tools/install.sh`. Der LaunchAgent setzt bewusst
kein `KeepAlive` — „Beenden“ im Menü muss beenden heißen.

`./Tools/make-download.sh` baut stattdessen ein Universal-Programm (Apple
Silicon und Intel) als DMG nach `web/public/download/` — das ist das Paket, das
die Website anbietet. Universal geht nur von Hand: `swift build --arch arm64
--arch x86_64` verlangt ein vollständiges Xcode, das Übersetzen für die jeweils
andere Architektur einzeln nicht — `lipo` fügt die Fassungen danach zusammen.
Version, Größe und Prüfsumme schreibt das Skript nach
`web/src/lib/build-info.json`; die Website liest sie von dort, damit sie nicht
irgendwann etwas anderes behauptet als die Datei, die sie ausliefert.

### Signieren und notarisieren

Ohne Zertifikat wird ad hoc signiert — dann lehnt Gatekeeper den ersten
Doppelklick ab, und die Website erklärt den Umweg über das Kontextmenü. Mit
einem Developer-ID-Zertifikat entfällt beides. Die Notarisierung selbst kostet
nichts extra; sie ist in der Mitgliedschaft im Apple Developer Program
enthalten.

```bash
# einmalig: Zugangsdaten in den Schlüsselbund (fragt das app-spezifische
# Passwort interaktiv ab, es landet nicht in der Verlaufsdatei der Shell)
xcrun notarytool store-credentials connectionlimit \
  --apple-id <apple-id> --team-id <team-id>

CONNLIMIT_NOTARY_PROFILE=connectionlimit ./Tools/make-download.sh
```

Das Skript signiert dann mit Hardened Runtime und Zeitstempel, reicht Programm
und Abbild einzeln ein, heftet beide Tickets an und trägt `notarized: true` in
die Bauangaben ein. Damit verschwindet der Gatekeeper-Schritt von der Website
von selbst — behaupten kann sie es nicht, sie liest es aus dem Bau.

Das Zertifikat wird nicht gesucht, sondern gefunden: Ohne
`CONNLIMIT_SIGN_IDENTITY` nimmt das Skript das erste
„Developer ID Application“ aus dem Schlüsselbund.

Alles rückgängig macht `./Tools/uninstall.sh`: hebt zuerst alle Sperren auf,
entfernt dann Autostart, App und Verknüpfung. Die Messdaten bleiben, sofern
nicht `CONNLIMIT_KEEP_DATA=0` gesetzt ist.

## Loslegen

```bash
connlimit doctor                    # Was ist auf diesem Mac verfügbar?
connlimit net set current teuer     # Aktuelles Netz einstufen
connlimit budget set 5GB --until 2026-09-06
connlimit run -v                    # Hintergrunddienst starten
```

Solange ein Netz **nicht eingestuft** ist, sperrt das Werkzeug bewusst nichts.
Beim ersten Start ist auch das Heim-WLAN unbekannt; dort ungefragt Dienste
einzufrieren wäre die falsche Art Überraschung.

## Befehle

| | |
|---|---|
| `tracked [--active] [--limit 30]` | Dauerliste: jeder Dienst, der je Daten brauchte |
| `top [--since 1h\|today\|7d] [--metered]` | Verbrauch pro Dienst im Zeitraum |
| `watch` | Live-Ansicht, wer gerade sendet |
| `history <dienst> [--since 24h] [--bucket 1h]` | Mengenverlauf über die Zeit |
| `events [<dienst>] [--attempts]` | Protokoll: Sperren, Freigaben, Durchbrüche |
| `status` | Netz, Profil, Budget, aktive Sperren |
| `services [--class sync]` | Dienstkatalog mit den jeweiligen Hebeln |
| `block <dienst> [--for 30m]` | Sperren, wahlweise befristet |
| `allow <dienst> [--for 30m]` | Freigeben; mit `--for` läuft die Freigabe ab |
| `unblock-all` | Not-Aus |
| `profile <aus\|sparsam\|urlaub\|notfall\|auto>` | Stufe setzen |
| `profile edit <stufe> <klassen…>` | Festlegen, was eine Stufe sperrt |
| `except <allow\|block\|clear> <dienst>` | Dauerhafte Ausnahme vom Profil |
| `reset <dienst> \| --all` | Dauerliste zurücksetzen |
| `net [list\|set\|name]` | Netze einstufen und benennen |
| `budget [show\|set\|clear]` | Reisebudget |
| `run [--read-only] [-v]` | Hintergrunddienst |
| `doctor` | Verfügbarkeitsprüfung |

Der nützlichste Griff im Alltag ist `allow <dienst> --for 30m`: der Dienst wird
für ein Zeitfenster freigegeben und danach automatisch wieder gesperrt. Danach
zeigt das Werkzeug, was die Freigabe gekostet hat — *„Dropbox: 240 MB in 30
Minuten"*. Diese Rückmeldung ist der eigentliche Lerneffekt.

## Was es kann — und was nicht

Gemessen wird über `nettop`. Das liefert Byte-Zähler pro Prozess ohne
Sonderrechte, ist aber ein **Stichprobenverfahren**: Prozesse, die zwischen
zwei Messungen entstehen und vergehen, fehlen. Die Zahlen sind gute Schätzungen,
keine Abrechnung.

Beim Sperren wird es unangenehmer. macOS bietet ohne Apple-Entitlement **keinen**
Weg, einer einzelnen App nur das Netz zu entziehen. Deshalb gestaffelte Hebel:

| Hebel | Wirkung | Rechte |
|---|---|---|
| **Systemdienst anhalten** | `launchctl kill SIGSTOP` — sauber, vollständig reversibel, stoppt das Volumen an der Quelle | root |
| **Ziel-Adressen sperren** | eigener PF-Anchor; die App bleibt bedienbar, aber CDN-Adressen können ausweichen | root + `install-pf` |
| **App einfrieren** | `SIGSTOP` — friert die **ganze** App ein, nicht nur ihr Netz | keine |

Für reine Sync-Clients ist Einfrieren genau das Gewünschte. Für Mail oder
Browser ist es grob; die Oberfläche schreibt das an jede betroffene Zeile.

**Ohne `sudo` bleibt nur der letzte Hebel.** Dienste, deren Hebel alle root
brauchen — macOS-Update, iCloud, Time Machine — laufen dann trotz aktivem
Profil weiter. Das Werkzeug meldet das ausdrücklich, statt „Urlaubsmodus aktiv"
anzuzeigen, während die größten Posten munter weiterladen.

Echtes Blocken pro App ginge mit einem `NEFilterDataProvider` als System
Extension. Das verlangt Apple Developer Program, ein von Apple freizugebendes
Entitlement und Xcode. Die Architektur hält den Platz dafür frei (`Enforcer`-
Protokoll), umgesetzt ist es nicht.

## Sicherheitsnetz

Eine App mit diesen Befugnissen darf keine Spuren hinterlassen:

- Jede Sperre bekommt eine **Quittung in der Datenbank, bevor** sie gesetzt wird.
  Ein Absturz dazwischen hinterlässt eine wirkungslose Quittung — harmlos.
  Andersherum bliebe eine eingefrorene App ohne jede Spur zurück.
- **Nie den eigenen Prozess oder einen seiner Vorfahren einfrieren.** Wird das
  Werkzeug aus einem Terminal heraus bedient, ist dieses Terminal ein Vorfahre —
  und ein eingefrorenes Terminal kann den Befehl zum Auftauen nicht mehr
  absetzen. Die Sperre wäre endgültig.
- Beim Start räumt die Wiederherstellung auf: abgelaufene Timer, tote Prozesse,
  Regeln aus einem anderen Netz. **Im Zweifel wird freigegeben.**
- Beim Beenden fallen alle Profil-Sperren. Manuelle Sperren bleiben — die hat
  der Nutzer bewusst gesetzt.
- PF-Regeln liegen in einem eigenen Anchor; `/etc/pf.conf` wird vor der Änderung
  gesichert, `uninstall-pf` stellt den Ausgangszustand wieder her.
- `connlimit unblock-all` hebt alles auf, unabhängig vom Zustand der Datenbank.
- Ein Reset der Dauerliste löscht **keine** Messdaten — daran hängt das Budget.

## Aufbau

```
Sources/
  ConnLimitCore/       Sampling · Katalog · Netzerkennung · Policy · Enforcement · Store
  connlimit/           CLI
  ConnectionLimitApp/  SwiftUI-Menüleiste und Fenster
  selftest/            Prüfsuite als eigenes Programm
Tools/                 Bauen, installieren, Symbol zeichnen, Bildschirmfotos aufnehmen
web/                   Website (Vite + React)
.knowledgebase/        Konzept, Technik-Recherche, Dienstkatalog, Roadmap
```

Die Prüfsuite läuft als eigenständiges Programm statt unter XCTest: beide
Test-Frameworks setzen ein vollständiges Xcode voraus, hier sind nur die
Command Line Tools installiert.

Daten liegen unter
`~/Library/Application Support/at.mitsol.connectionlimit/` — `connlimit.db`
(SQLite) und die optionale `catalog.json` für eigene Diensteinträge.

## Website

```bash
cd web
npm install
npm run dev        # Entwicklung
npm run build      # nach web/dist/
```

Die Seite baut die Oberfläche als echtes Markup nach und spielt in Bewegung
durch, was das Werkzeug tut — dazu die Bildschirmfotos aus `Tools/make-screenshots.sh`.

Hintergrund, Begründungen und die vollständige Liste der technischen Grenzen:
**[.knowledgebase/](.knowledgebase/)**

## Lizenz

MIT — siehe [LICENSE](LICENSE).
