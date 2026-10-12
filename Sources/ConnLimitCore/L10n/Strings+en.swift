// Englische Übersetzung.
//
// Schlüssel ist der deutsche Ausgangstext, genau so, wie er im Quelltext
// steht. Fehlt ein Eintrag, erscheint der deutsche Text — sichtbar, aber nie
// kaputt. `Tools/check-l10n.sh` findet fehlende Einträge, die Prüfsuite
// gleicht die Platzhalter ab.
//
// Begriffe, die überall gleich bleiben müssen (App, Terminal, Website):
//   frei / teuer / begrenzt     → free / metered / limited
//   Aus / Sparsam / Urlaubsmodus / Notfall → Off / Frugal / Vacation / Emergency
//   gesperrt / freigegeben      → blocked / unblocked
//   trotz Sperre aktiv          → active despite block
//   Durchbruch                  → leak
//   Hebel                       → lever

enum Strings {
    static let en: [String: String] = [
        // MARK: Kern — Hintergrunddienst und Fehler
        "Katalogdatei %@ ignoriert — %@": "Catalog file %@ ignored — %@",
        "Wiederherstellung: freigegeben — %@": "Recovery: unblocked — %@",
        "Netzwechsel: %@ [%@]": "Network change: %@ [%@]",
        "Freigabe beendet: %@ hat %@ verbraucht": "Unblock window ended: %@ used %@",
        "Sperre abgelaufen: %@": "Block expired: %@",
        "Automatik: Stufe %@ — %@": "Automation: tier %@ — %@",
        "Fehler im Takt: %@": "Error in cycle: %@",
        "Beende — gebe Profil-Sperren frei": "Stopping — releasing profile blocks",
        "Gesperrt: %@": "Blocked: %@",
        "Freigegeben: %@": "Unblocked: %@",
        "Fehlgeschlagen: %@ — %@": "Failed: %@ — %@",
        "falscher Hebel-Typ": "wrong lever type",
        "Timer abgelaufen": "timer expired",
        "Profil ist nicht mehr aktiv": "profile no longer active",
        "Prozesse existieren nicht mehr": "processes no longer exist",
        "Regel galt für ein anderes Netz": "rule was for a different network",
        "'%@' ist als systemkritisch eingestuft und kann nicht gesperrt werden.":
            "'%@' is classed as essential and cannot be blocked.",
        "Für '%@' greift gerade kein Hebel (läuft der Dienst überhaupt?).":
            "No lever applies to '%@' right now (is the service running at all?).",
        "Der Hebel '%@' braucht root — bitte mit sudo starten.":
            "The lever '%@' needs root — please run with sudo.",
        "Hebel '%@' fehlgeschlagen: %@": "Lever '%@' failed: %@",
        "PF-Anchor ist nicht installiert. Einmalig 'sudo connlimit install-pf' ausführen.":
            "PF anchor is not installed. Run 'sudo connlimit install-pf' once.",
        "kein Job konnte gestoppt werden": "no job could be stopped",
        "keine der Domains ließ sich auflösen — ohne Adressen gibt es nichts zu sperren":
            "none of the domains could be resolved — without addresses there is nothing to block",
        "PID %@ (%@) darf nicht eingefroren werden": "PID %@ (%@) may not be frozen",
        "keine PID konnte eingefroren werden": "no PID could be frozen",
        "Datenbank konnte nicht geöffnet werden: %@": "Database could not be opened: %@",
        "SQL-Fehler beim Vorbereiten: %@": "SQL error while preparing: %@",
        "SQL-Fehler bei der Ausführung: %@": "SQL error while executing: %@",
        "Konnte '%@' nicht starten: %@": "Could not launch '%@': %@",
        "'%@' fehlgeschlagen (Status %@): %@": "'%@' failed (status %@): %@",
        "Weniger als 5 % des Volumens übrig — Notfallbetrieb.":
            "Less than 5 % of the volume left — emergency mode.",
        "Weniger als 15 % des Volumens übrig.": "Less than 15 % of the volume left.",
        "Hochrechnung liegt über dem Tagesbudget (%@ statt %@).":
            "Projection is above the daily budget (%@ instead of %@).",

        // MARK: Zeitangaben
        "vor %@ s": "%@ s ago",
        "vor %@ min": "%@ min ago",
        "vor %@ h": "%@ h ago",
        "vor 1 Tag": "1 day ago",
        "vor %@ Tagen": "%@ days ago",
        "vor %@ T": "%@ d ago",
        "gestern %@": "yesterday %@",
        "1 Tag": "1 day",
        "%@ Tage": "%@ days",
        "Tage": "days",

        // MARK: Netze, Stufen, Klassen
        "frei": "free",
        "teuer": "metered",
        "begrenzt": "limited",
        "unbekannt": "unknown",
        "Offline": "Offline",
        "iPhone-Hotspot": "iPhone hotspot",
        "WLAN": "Wi-Fi",
        "Kabel": "Ethernet",
        "Netz": "Network",
        "Aus": "Off",
        "Sparsam": "Frugal",
        "Urlaubsmodus": "Vacation",
        "Notfall": "Emergency",
        "keine Sperren": "no blocks",
        "Updates, Backups, Telemetrie, Medien": "Updates, backups, telemetry, media",
        "zusätzlich Cloud-Sync": "plus cloud sync",
        "zusätzlich E-Mail und Browser": "plus mail and browsers",
        "im Rahmen": "on track",
        "leicht drüber": "slightly over",
        "zu schnell": "too fast",
        "durch Profil": "by profile",
        "manuell": "manual",
        "befristet": "timed",
        "Budget-Automatik": "budget automation",
        "friert die App komplett ein, nicht nur ihr Netz":
            "freezes the whole app, not just its network",
        "sperrt bekannte Ziel-Adressen; CDN-Adressen können ausweichen":
            "blocks known destination addresses; CDN addresses can dodge it",
        "Systemdienst anhalten": "Pause system service",
        "App einfrieren": "Freeze app",
        "Ziel-Adressen sperren": "Block destination addresses",
        "Pause-Befehl der App": "App's own pause command",
        "Netzwerkfilter": "Network filter",
        "Systemkritisch": "Essential",
        "Updates": "Updates",
        "Backup": "Backup",
        "Telemetrie": "Telemetry",
        "Medien": "Media",
        "Cloud-Sync": "Cloud sync",
        "E-Mail": "Mail",
        "Browser": "Browser",
        "Messenger": "Messaging",
        "Sonstiges": "Other",
        "gesperrt": "blocked",
        "freigegeben": "unblocked",
        "trotz Sperre aktiv": "active despite block",
        "Zählung zurückgesetzt": "count reset",
        "gesperrt seit %@": "blocked since %@",

        // MARK: App — Menüleiste
        "Dieses Netz ist noch nicht eingestuft — bis dahin wird nichts gesperrt.":
            "This network isn't classified yet — nothing is blocked until it is.",
        "Läuft trotz Profil weiter, weil dafür sudo nötig ist: %@":
            "Still running despite the profile, because it needs sudo: %@",
        "Trotz Sperre aktiv: %@": "Active despite block: %@",
        "Verbrauch liegt über dem Tagesbudget.": "Usage is above the daily budget.",
        "%@ und %@ weitere": "%@ and %@ more",
        "ConnectionLimit konnte nicht starten": "ConnectionLimit couldn't start",
        "Die Datenbank liegt unter %@.": "The database is at %@.",
        "Beenden": "Quit",
        "Heute %@": "Today %@",
        "gerade still": "idle right now",
        "Profil": "Profile",
        "angepasst": "customised",
        "von Hand": "manual",
        "Zurück zur Automatik: Die Stufe folgt wieder dem Netz (%@).":
            "Back to automatic: the tier follows the network again (%@).",
        "automatisch": "automatic",
        "Die Stufe folgt der Einstufung des Netzes.": "The tier follows the network's classification.",
        "Freies Netz: Hier wird nie gesperrt. „%@“ gilt ab dem nächsten teuren Netz.":
            "Free network: nothing is ever blocked here. “%@” applies from the next metered network.",
        "Budget": "Budget",
        "%@ übrig": "%@ left",
        "Heute %@ von %@ · noch %@": "Today %@ of %@ · %@ left",
        "Dienste": "Services",
        "%@ aktiv": "%@ active",
        "Noch nichts gesehen — die Messung läuft.": "Nothing seen yet — measuring.",
        "… und %@ weitere": "… and %@ more",
        "Gesperrt (%@)": "Blocked (%@)",
        "Frei": "Unblock",
        "frei in %@": "free in %@",
        "Freigegeben auf Zeit": "Unblocked for a while",
        "noch %@ · bisher %@": "%@ left · %@ so far",
        "Alles freigeben": "Unblock all",
        "Fenster öffnen": "Open window",
        "Beenden — offene Sperren werden vorher aufgehoben": "Quit — open blocks are lifted first",
        "Trotz Sperre sind Daten geflossen": "Data flowed despite the block",
        "Freigeben": "Unblock",
        "15 Minuten freigeben": "Unblock for 15 minutes",
        "1 Stunde freigeben": "Unblock for 1 hour",
        "Jetzt sperren": "Block now",
        "30 Minuten sperren": "Block for 30 minutes",
        "2 Stunden sperren": "Block for 2 hours",
        "Aus der Liste entfernen": "Remove from list",
        "Systemkritisch — bewusst nicht sperrbar": "Essential — deliberately not blockable",
        "Sprache": "Language",
        "Wie macOS": "Same as macOS",

        // MARK: App — Theme
        "aktiv": "active",
        "still": "idle",
        "Flatrate — es wird nichts gesperrt und nichts aufs Budget gezählt.":
            "Flat rate — nothing is blocked and nothing counts towards the budget.",
        "Teuer — hier greift der Urlaubsmodus, der Verbrauch zählt aufs Budget.":
            "Metered — vacation mode applies here and usage counts towards the budget.",
        "Begrenzt — sparsames Profil, Verbrauch zählt aufs Budget.":
            "Limited — frugal profile, usage counts towards the budget.",
        "Noch nicht eingestuft — solange wird bewusst nichts gesperrt.":
            "Not classified yet — until then nothing is blocked, on purpose.",
        "Kein Verlauf": "No history",
        "Verlauf der letzten %@ Tage": "History of the last %@ days",
        "Verlauf der letzten %@ Stunden": "History of the last %@ hours",

        // MARK: App — Fenster
        "Sehen": "See",
        "Begrenzen": "Limit",
        "Einrichten": "Set up",
        "Verbrauch": "Usage",
        "Protokoll": "Log",
        "Profile": "Profiles",
        "Netze": "Networks",
        "Alle": "All",
        "Aktiv": "Active",
        "Gesperrt": "Blocked",
        "Durchbrüche": "Leaks",
        "Zählung für alle Dienste zurücksetzen?": "Reset the count for all services?",
        "Liste leeren": "Clear list",
        "Abbrechen": "Cancel",
        "Die Liste beginnt von vorn. Messdaten und Budget bleiben unberührt — Dienste erscheinen wieder, sobald sie das nächste Mal Daten brauchen.":
            "The list starts over. Measurements and budget stay untouched — services reappear as soon as they use data again.",
        "Heute": "Today",
        "seit Mitternacht": "since midnight",
        "Gerade": "Right now",
        "Beobachtet": "Tracked",
        "Dienste in der Liste": "services in the list",
        "keine Durchbrüche": "no leaks",
        "%@ mit Durchbruch": "%@ leaking",
        "Jeder Dienst bleibt in der Liste, bis du ihn zurücksetzt":
            "Every service stays in the list until you reset it",
        "gezählt seit %@": "counted since %@",
        "Suchen": "Search",
        "Zurücksetzen": "Reset",
        "Leert die Liste. Messdaten und Budget bleiben erhalten.":
            "Clears the list. Measurements and budget are kept.",
        "Noch nichts gesehen": "Nothing seen yet",
        "Die Messung läuft, solange diese App geöffnet ist. Wer Daten braucht, landet hier — und bleibt stehen, auch wenn er wieder still ist.":
            "Measuring runs while this app is open. Whatever uses data lands here — and stays, even once it goes quiet again.",
        "Keine Durchbrüche": "No leaks",
        "Kein Treffer": "No match",
        "Es ist noch nie etwas durch eine gesetzte Sperre gekommen.":
            "Nothing has ever got through a block.",
        "trotz Sperre": "despite block",
        "heute %@": "today %@",
        "Details und Verlauf …": "Details and history …",
        "gerade aktiv": "active now",
        "zuletzt %@": "last %@",
        "%@× trotz Sperre · %@": "%@× despite block · %@",
        "Sperren": "Block",
        "Fertig": "Done",
        "Gesamt": "Total",
        "seit %@": "since %@",
        "Empfangen": "Received",
        "↑ %@ gesendet": "↑ %@ sent",
        "Menge über die Zeit": "Volume over time",
        "Stundenfenster der letzten 24 Stunden": "Hourly windows over the last 24 hours",
        "Tagesfenster der letzten 7 Tage": "Daily windows over the last 7 days",
        "24 Stunden": "24 hours",
        "7 Tage": "7 days",
        "Spitze %@ je Fenster": "peak %@ per window",
        "jetzt": "now",
        "Keine Messdaten in diesem Zeitraum.": "No measurements in this period.",
        "Zeitpunkte von Sperre, Freigabe und Verkehr trotz Sperre":
            "When it was blocked, unblocked, and when traffic got through a block",
        "Noch nichts protokolliert.": "Nothing logged yet.",
        "Hebel": "Levers",
        "Womit dieser Dienst gestoppt wird": "How this service is stopped",
        "Kein Hebel hinterlegt — dieser Dienst lässt sich nicht sperren.":
            "No lever defined — this service can't be blocked.",
        "braucht sudo": "needs sudo",
        "Diesen Dienst aus der Liste entfernen": "Remove this service from the list",
        "Wann etwas gesperrt oder freigegeben wurde — und wann trotz gesetzter Sperre Daten geflossen sind.":
            "When something was blocked or unblocked — and when data flowed despite a block.",
        "Nur Durchbrüche": "Leaks only",
        "%@ Einträge · 14 Tage": "%@ entries · 14 days",
        "Noch nichts protokolliert": "Nothing logged yet",
        "Durch eine gesetzte Sperre ist bisher nichts gekommen.":
            "Nothing has got through a block so far.",
        "Sobald du etwas sperrst oder freigibst, steht es hier mit Zeitpunkt.":
            "As soon as you block or unblock something, it shows up here with a timestamp.",
        "Eine Stufe sperrt Klassen, keine einzelnen Dienste — so greift sie auch für Dienste, die es beim Anlegen noch nicht gab. Was eine Stufe sperrt, legst du hier fest.":
            "A tier blocks classes, not individual services — so it also covers services that didn't exist when it was set up. You decide here what each tier blocks.",
        "Immer geschützt": "Always protected",
        "Diese Klasse lässt sich keiner Stufe zuordnen — sonst könnte sich das Werkzeug selbst oder das VPN aussperren.":
            "This class can't be assigned to any tier — otherwise the tool could lock out itself or the VPN.",
        "hart geschützt": "hard-protected",
        "Von Hand gewählt: %@": "Chosen manually: %@",
        "Automatisch: Das Netz bestimmt die Stufe": "Automatic: the network decides the tier",
        "Gilt in jedem teuren oder begrenzten Netz, bis du zur Automatik zurückkehrst. In freien Netzen wird nie gesperrt.":
            "Applies on every metered or limited network until you go back to automatic. Nothing is ever blocked on free networks.",
        "Frei → Aus · Begrenzt → Sparsam · Teuer → Urlaubsmodus. Ein unbekanntes Netz sperrt nichts, bis du es einstufst.":
            "Free → Off · Limited → Frugal · Metered → Vacation. An unknown network blocks nothing until you classify it.",
        "Zurück zur Automatik": "Back to automatic",
        "Eine höhere Stufe sperrt weniger als eine niedrigere": "A higher tier blocks less than a lower one",
        "Betroffen: %@. Die Budget-Automatik stuft nur nach oben — sie würde dabei lockern.":
            "Affected: %@. Budget automation only escalates — here it would loosen things.",
        "Voreinstellung": "Default",
        "Aktivieren": "Activate",
        "Sperrt nichts.": "Blocks nothing.",
        "Sperrt: %@": "Blocks: %@",
        "Der Katalog: was das Werkzeug kennt und womit es den Dienst stoppt. Einzelne Dienste lassen sich dauerhaft vom Profil ausnehmen.":
            "The catalogue: what the tool knows and how it stops each service. Individual services can be permanently exempted from the profile.",
        "Dienst suchen": "Search services",
        "nie sperrbar": "never blockable",
        "nur manuell": "manual only",
        "ab „%@“": "from “%@”",
        "immer erlaubt": "always allowed",
        "immer gesperrt": "always blocked",
        "Immer erlauben": "Always allow",
        "Immer sperren": "Always block",
        "Ausnahme entfernen": "Remove exception",
        "Netze werden an der MAC-Adresse ihres Routers wiedererkannt — dafür braucht die App keine Ortungsdienste. Die Einstufung entscheidet, ob gesperrt wird und ob der Verbrauch aufs Budget zählt.":
            "Networks are recognised by their router's MAC address — the app needs no Location Services for that. The classification decides whether anything is blocked and whether usage counts towards the budget.",
        "verbunden": "connected",
        "Reise": "Trip",
        "Nur Verbrauch in Netzen der Klasse „teuer“ oder „begrenzt“ zählt.":
            "Only usage on “metered” or “limited” networks counts.",
        "Übrig": "Left",
        "von %@": "of %@",
        "Restlaufzeit": "Time left",
        "Tagesbudget": "Daily budget",
        "Hochrechnung": "Projection",
        "für heute": "for today",
        "Budget löschen": "Delete budget",
        "Neues Budget": "New budget",
        "Volumen und Enddatum des Tarifs — daraus ergibt sich das Tagesbudget.":
            "Your plan's volume and end date — the daily budget follows from them.",
        "Volumen": "Volume",
        "Bis": "Until",
        "Name": "Name",
        "Setzen": "Set",
        "Volumen nicht verstanden — z. B. „5 GB“ oder „500 MB“":
            "Volume not understood — e.g. “5 GB” or “500 MB”",
        "Automatik": "Automation",
        "Stuft hoch, wenn die Hochrechnung über dem Tagesbudget liegt oder weniger als 15 % übrig sind. Zurückgestuft wird nur von Hand — sonst pendelt das Profil.":
            "Escalates when the projection is above the daily budget or less than 15 % is left. Stepping back down is manual only — otherwise the profile would flip back and forth.",
        "Bei knappem Budget automatisch hochstufen": "Escalate automatically when the budget runs low",

        // MARK: Terminal
        "'%@' ist mehrdeutig:": "'%@' is ambiguous:",
        "Kein Dienst gefunden für '%@'. 'connlimit services' zeigt alle.":
            "No service found for '%@'. 'connlimit services' lists them all.",
        "Kein Dienst gefunden für '%@'. 'connlimit tracked' zeigt die beobachteten, 'connlimit services' den Katalog.":
            "No service found for '%@'. 'connlimit tracked' shows the tracked ones, 'connlimit services' the catalogue.",
        "manuell gesetzt": "set manually",
        "folgt dem Netz": "follows the network",
        "Automatik aus": "automation off",
        "%@ von %@ übrig": "%@ of %@ left",
        "heute %@ · Tagesbudget %@ · Hochrechnung %@": "today %@ · daily budget %@ · projection %@",
        "nicht gesetzt — 'connlimit budget set 5GB --until 2026-09-06'":
            "not set — 'connlimit budget set 5GB --until 2026-09-06'",
        "Keine aktiven Sperren.": "No active blocks.",
        "Aktive Sperren (%@)": "Active blocks (%@)",
        "endet in %@": "ends in %@",
        "Freigaben auf Zeit": "Timed unblocks",
        "Immer erlaubt: ": "Always allowed: ",
        "Immer gesperrt: ": "Always blocked: ",
        "connlimit block <dienst> [--for 30m]": "connlimit block <service> [--for 30m]",
        "Dauer nicht verstanden: '%@' (z. B. 30m, 2h)": "Duration not understood: '%@' (e.g. 30m, 2h)",
        "%@ gesperrt": "%@ blocked",
        "Hebel: %@": "lever: %@",
        "connlimit allow <dienst> [--for 30m]": "connlimit allow <service> [--for 30m]",
        "%@ für %@ freigegeben": "%@ unblocked for %@",
        "Danach greift das Profil wieder. Der Verbrauch in diesem Fenster wird ausgewiesen.":
            "After that the profile applies again. Usage during this window is reported.",
        "%@ freigegeben": "%@ unblocked",
        "Alle Sperren aufgehoben (%@)": "All blocks lifted (%@)",
        "Hinweis: PF- und launchd-Sperren brauchen root — ggf. 'sudo connlimit unblock-all' nachziehen.":
            "Note: PF and launchd blocks need root — run 'sudo connlimit unblock-all' if needed.",
        "Profil: ": "Profile: ",
        "Diese Stufen sperren weniger als eine niedrigere: %@":
            "These tiers block less than a lower one: %@",
        "Die Budget-Automatik stuft nur hoch — sie würde dabei lockern.":
            "Budget automation only escalates — here it would loosen things.",
        "connlimit profile <aus|sparsam|urlaub|notfall|auto>":
            "connlimit profile <off|frugal|vacation|emergency|auto>",
        "connlimit profile edit <stufe> <klassen…>   Belegung ändern":
            "connlimit profile edit <tier> <classes…>   change what a tier blocks",
        "Profil folgt wieder dem Netz": "Profile follows the network again",
        "Unbekanntes Profil '%@'. Erlaubt: aus, sparsam, urlaub, notfall, auto":
            "Unknown profile '%@'. Allowed: off, frugal, vacation, emergency, auto",
        "connlimit profile edit <sparsam|urlaub|notfall> <klassen…>":
            "connlimit profile edit <frugal|vacation|emergency> <classes…>",
        "Klassen: ": "Classes: ",
        "Die Stufe „Aus“ sperrt nichts — das ist nicht verhandelbar.":
            "The “Off” tier blocks nothing — that is not negotiable.",
        "%@ wieder auf Voreinstellung: ": "%@ back to default: ",
        "Setzen (Komma oder Leerzeichen, ersetzt die ganze Belegung):":
            "Set (comma or space separated, replaces the whole assignment):",
        "Zurück auf Voreinstellung:": "Back to default:",
        "Unbekannte Klasse '%@'. Erlaubt: ": "Unknown class '%@'. Allowed: ",
        "„%@“ ist hart geschützt und lässt sich keiner Stufe zuordnen.":
            "“%@” is hard-protected and can't be assigned to a tier.",
        "%@ sperrt jetzt: %@": "%@ now blocks: %@",
        "Diese Stufe sperrt weniger als eine niedrigere — die Budget-Automatik würde beim Hochstufen lockern.":
            "This tier blocks less than a lower one — budget automation would loosen things when escalating.",
        "gesperrt: ": "blocked: ",
        "freigegeben: ": "unblocked: ",
        "braucht sudo: ": "needs sudo: ",
        "Diese Dienste laufen weiter. 'sudo connlimit profile …' sperrt sie wirklich.":
            "These services keep running. 'sudo connlimit profile …' really blocks them.",
        "keine Änderung": "no change",
        "Verbrauch seit Beginn der Aufzeichnung": "Usage since recording began",
        "Verbrauch seit %@ min": "Usage over the last %@ min",
        "Verbrauch seit %@ h": "Usage over the last %@ h",
        "Verbrauch seit %@ Tagen": "Usage over the last %@ days",
        "Netz: %@ [%@]": "Network: %@ [%@]",
        "Noch keine Messdaten. 'connlimit run' im Hintergrund starten oder 'connlimit watch' für eine Live-Ansicht.":
            "No measurements yet. Start 'connlimit run' in the background, or 'connlimit watch' for a live view.",
        "DIENST": "SERVICE",
        "KLASSE": "CLASS",
        "GESAMT": "TOTAL",
        "ANTEIL": "SHARE",
        "Gesamt: ": "Total: ",
        "Strg-C zum Beenden": "Ctrl-C to quit",
        "Netz: ": "Network: ",
        "Gerade keine nennenswerte Aktivität.": "No notable activity right now.",
        "RATE": "RATE",
        "AKTIVITÄT": "ACTIVITY",
        "Summe: ": "Sum: ",
        "Bekannte Netze": "Known networks",
        "NAME": "NAME",
        "ZULETZT": "LAST",
        "connlimit net set <id|current> <frei|teuer|begrenzt>":
            "connlimit net set <id|current> <free|metered|limited>",
        "connlimit net name <id|current> \"Hotel WLAN\"": "connlimit net name <id|current> \"Hotel Wi-Fi\"",
        "Netz %@ ist jetzt %@": "Network %@ is now %@",
        "Verbrauch in diesem Netz zählt gegen das Budget.": "Usage on this network counts towards the budget.",
        "Die App wendet das passende Profil beim nächsten Abgleich an (spätestens nach 30 s).":
            "The app applies the matching profile at its next check (within 30 s).",
        "connlimit net name <id|current> \"Name\"": "connlimit net name <id|current> \"Name\"",
        "Netz %@ heißt jetzt %@": "Network %@ is now called %@",
        "Kein Budget gesetzt.": "No budget set.",
        "Verbraucht": "Used",
        "Hochrechnung %@": "projection %@",
        "Status": "Status",
        "Nur Traffic in teuren oder begrenzten Netzen zählt.": "Only traffic on metered or limited networks counts.",
        "connlimit budget set <5GB> --until <2026-09-06> [--label \"Italien\"]":
            "connlimit budget set <5GB> --until <2026-09-06> [--label \"Italy\"]",
        "--until <YYYY-MM-DD> fehlt oder ist unlesbar": "--until <YYYY-MM-DD> is missing or unreadable",
        "Das Enddatum liegt vor dem Beginn.": "The end date is before the start.",
        "Budget: %@ bis %@": "Budget: %@ until %@",
        "Tagesbudget: %@": "Daily budget: %@",
        "Budget gelöscht": "Budget deleted",
        "Ausnahmen": "Exceptions",
        "connlimit except allow <dienst>   — auch im Urlaubsmodus erlauben":
            "connlimit except allow <service>   — allow even in vacation mode",
        "connlimit except block <dienst>   — immer sperren": "connlimit except block <service>   — always block",
        "connlimit except clear <dienst>   — Ausnahme entfernen":
            "connlimit except clear <service>   — remove exception",
        "connlimit except <allow|block|clear> <dienst>": "connlimit except <allow|block|clear> <service>",
        "%@ bleibt immer erlaubt": "%@ stays allowed",
        "%@ ist systemkritisch und kann nicht gesperrt werden.": "%@ is essential and cannot be blocked.",
        "%@ ist immer gesperrt": "%@ is always blocked",
        "Ausnahme für %@ entfernt": "Exception for %@ removed",
        "connlimit läuft": "connlimit is running",
        "(nur messen, keine Sperren)": "(measuring only, no blocks)",
        "Systemprüfung": "System check",
        "Messung verfügbar": "measurement available",
        "fehlt — ohne geht nichts": "missing — nothing works without it",
        "Netzerkennung": "Network detection",
        "offline": "offline",
        "nicht ermittelbar — Netz-ID weniger stabil": "not available — network ID less stable",
        "Datenbank": "Database",
        "launchd- und PF-Hebel verfügbar": "launchd and PF levers available",
        "ohne sudo nur der Hebel 'App einfrieren'": "without sudo only the 'Freeze app' lever",
        "installiert": "installed",
        "nicht installiert — 'sudo connlimit install-pf' für Domain-Sperren":
            "not installed — 'sudo connlimit install-pf' for domain blocks",
        "Prozessliste": "Process list",
        "%@ Prozesse sichtbar": "%@ processes visible",
        "Offene Sperren": "Open blocks",
        "keine": "none",
        "%@ — 'connlimit status' zeigt sie": "%@ — 'connlimit status' shows them",
        "Was welcher Hebel wirklich tut, steht in der README.": "What each lever really does is in the README.",
        "Braucht root: %@": "Needs root: %@",
        "PF-Anchor ist bereits installiert.": "PF anchor is already installed.",
        "Fügt %@ zu /etc/pf.conf hinzu.": "Adds %@ to /etc/pf.conf.",
        "Eine Sicherung wird unter /etc/pf.conf.connlimit-backup abgelegt.":
            "A backup is stored at /etc/pf.conf.connlimit-backup.",
        "PF-Anchor installiert und Regelsatz neu geladen": "PF anchor installed and ruleset reloaded",
        "PF-Anchor entfernt, alle Regeln geleert": "PF anchor removed, all rules flushed",
        "Sprache: %@": "Language: %@",
        "wie macOS": "same as macOS",
        "gilt für App und Terminal": "applies to app and terminal",
        "Getrackte Dienste": "Tracked services",
        "Noch nichts gesehen. 'connlimit run' im Hintergrund starten oder die App öffnen — die Liste füllt sich beim Messen.":
            "Nothing seen yet. Start 'connlimit run' in the background or open the app — the list fills up as it measures.",
        "HEUTE": "TODAY",
        "VERLAUF 24 h": "HISTORY 24 h",
        "gerade": "now",
        "%@× trotz Sperre aktiv · %@": "%@× active despite block · %@",
        "%@ Dienste": "%@ services",
        "%@ gerade aktiv": "%@ active now",
        "Zurücksetzen: connlimit reset --all  ·  einzeln: connlimit reset <dienst>":
            "Reset: connlimit reset --all  ·  single: connlimit reset <service>",
        "connlimit history <dienst> [--since 24h] [--bucket 1h]":
            "connlimit history <service> [--since 24h] [--bucket 1h]",
        "Verlauf: %@": "History: %@",
        "Fenster %@": "window %@",
        "Unter einer Stunde reichen nur die Rohdaten der letzten 48 h.":
            "Below one hour, only the raw data of the last 48 h is detailed enough.",
        "Protokoll: %@": "Log: %@",
        "Keine Einträge. Protokolliert werden Sperren, Freigaben und Verkehr trotz Sperre.":
            "No entries. Blocks, unblocks and traffic despite a block are logged.",
        "Nur Durchbrüche: connlimit events --attempts": "Leaks only: connlimit events --attempts",
        "Zählung zurückgesetzt — %@ Dienste aus der Liste entfernt":
            "Count reset — %@ services removed from the list",
        "Messdaten und Budget bleiben unberührt; die Liste füllt sich neu.":
            "Measurements and budget stay untouched; the list fills up again.",
        "connlimit reset <dienst>   oder   connlimit reset --all":
            "connlimit reset <service>   or   connlimit reset --all",
        "%@ steht nicht in der Liste.": "%@ isn't in the list.",
        "%@ aus der Liste entfernt": "%@ removed from the list",
        "Erscheint wieder, sobald der Dienst das nächste Mal Daten braucht.":
            "Reappears as soon as the service uses data again.",
        "<dienst>": "<service>",
        "Datenverbindungen auf dem Mac sehen und begrenzen": "see and limit data connections on the Mac",
        "SEHEN": "SEE",
        "Dauerliste: jeder Dienst, der je Daten brauchte": "Persistent list: every service that ever used data",
        "Verbrauch pro Dienst im Zeitraum": "Usage per service over a period",
        "Live-Ansicht, wer gerade sendet": "Live view of who is sending right now",
        "Mengenverlauf über die Zeit": "Volume over time",
        "Protokoll: Sperren, Freigaben, Verkehr trotz Sperre": "Log: blocks, unblocks, traffic despite a block",
        "Netz, Profil, Budget, aktive Sperren": "Network, profile, budget, active blocks",
        "Dienstkatalog mit Hebeln": "Service catalogue with levers",
        "BEGRENZEN": "LIMIT",
        "Dienst sperren, wahlweise befristet": "Block a service, optionally for a while",
        "Freigeben; mit --for befristet, danach wieder gesperrt":
            "Unblock; with --for only for a while, then blocked again",
        "Not-Aus: alle Sperren aufheben": "Emergency stop: lift all blocks",
        "profile [aus|sparsam|urlaub|notfall|auto]": "profile [off|frugal|vacation|emergency|auto]",
        "Eskalationsstufe setzen oder anzeigen": "Set or show the escalation tier",
        "Dauerhafte Ausnahme vom Profil": "Permanent exception from the profile",
        "profile edit <stufe> <klassen…>": "profile edit <tier> <classes…>",
        "Festlegen, was eine Stufe sperrt": "Decide what a tier blocks",
        "Dauerliste zurücksetzen": "Reset the persistent list",
        "EINRICHTEN": "SET UP",
        "Netze einstufen (frei / teuer / begrenzt)": "Classify networks (free / metered / limited)",
        "Reisebudget, z. B. budget set 5GB --until 2026-09-06":
            "Trip budget, e.g. budget set 5GB --until 2026-09-06",
        "Hintergrunddienst: messen und durchsetzen": "Background service: measure and enforce",
        "Prüft, welche Hebel auf diesem Mac verfügbar sind": "Checks which levers are available on this Mac",
        "PF-Anchor für Domain-Sperren (root)": "PF anchor for domain blocks (root)",
        "Sprache von App und Terminal": "Language of app and terminal",
        "Konzept und Grenzen: README.md": "Concept and limits: README.md",
        "Unbekannter Befehl: %@": "Unknown command: %@",
        "Fehler: ": "Error: ",

        // MARK: Dienstkatalog — nur, was sich vom Markennamen unterscheidet
        "DNS-Auflösung": "DNS resolution",
        "Zeitabgleich": "Time sync",
        "Netzwerk-Stack": "Network stack",
        "Sicherheitsupdates": "Security updates",
        "iCloud Fotos": "iCloud Photos",
        "iCloud Sicherung": "iCloud Backup",
        "Apple Musik & TV": "Apple Music & TV",
        "Apple Diagnose": "Apple Diagnostics",
        "Microsoft Update & Telemetrie": "Microsoft Update & Telemetry",
        "Nachrichten": "Messages",
        "Ohne DNS funktioniert nichts. Verbraucht selbst kaum Volumen.":
            "Nothing works without DNS. Uses hardly any volume itself.",
        "Ein gesperrtes VPN würde die Verbindung ganz kappen.": "A blocked VPN would cut the connection entirely.",
        "Transportiert iMessage- und Mail-Hinweise. Sehr geringes Volumen — sperren lohnt nicht.":
            "Carries iMessage and mail notifications. Very little volume — not worth blocking.",
        "Malware-Definitionen. Klein und sicherheitsrelevant — bewusst nicht sperrbar.":
            "Malware definitions. Small and security-relevant — deliberately not blockable.",
        "Der mit Abstand größte einzelne Posten — ein macOS-Update sind mehrere GB.":
            "By far the largest single item — a macOS update is several GB.",
        "Image-Pulls sind schnell mehrere GB.": "Image pulls quickly add up to several GB.",
        "Nur relevant bei Netzwerk-Backupziel.": "Only relevant with a network backup destination.",
        "Fotos hängen separat an 'iCloud Fotos'.": "Photos are handled separately under 'iCloud Photos'.",
        "Lädt ganze Mediatheken nach — im Urlaub der teuerste Sync.":
            "Downloads entire libraries — the most expensive sync on a trip.",
        "Lädt Schriften und Updates ungefragt nach.": "Downloads fonts and updates without asking.",
        "Lädt Playlists im Hintergrund vor.": "Preloads playlists in the background.",
        "Spiele-Updates sind zweistellige GB-Beträge.": "Game updates run into double-digit GB.",
        "Spart wenig Volumen, funkt aber im Urlaub ohne Nutzen ständig.":
            "Saves little volume, but chatters constantly on a trip for no benefit.",
        "Einfrieren macht die App unbedienbar — besser Timer-Freigabe nutzen.":
            "Freezing makes the app unusable — better use a timed unblock.",
        "Lädt ganze Postfächer vor. Einfrieren macht die App unbedienbar.":
            "Preloads entire mailboxes. Freezing makes the app unusable.",
        "Meist der größte Posten. Sichtbar zu machen bringt mehr, als ihn zu sperren.":
            "Usually the largest item. Making it visible achieves more than blocking it.",
        "Video kostet viel — im Notfallmodus bewusst manuell sperren.":
            "Video is expensive — block it manually in emergency mode.",
    ]
}
