import type { ReactNode } from 'react'

/// Das deutsche Wörterbuch ist das Original — sein Typ ist der Vertrag, den
/// das englische erfüllen muss.

export interface TermLine {
  text: string
  tone?: 'dim' | 'green' | 'red' | 'amber' | 'head'
}

export interface TermProgram {
  command: string
  lines: TermLine[]
}

export interface InstallStep {
  title: string
  text: string
  code?: string
  codeNote?: string
}

export interface Card {
  title: string
  text: string
}

export interface Shot {
  id: string
  label: string
  caption: string
}

export const de = {
  meta: {
    title: 'ConnectionLimit — sehen, wer Datenvolumen verbraucht. Und es abdrehen.',
    description:
      'macOS zeigt keinen Verbrauch pro App und hat keinen Low-Data-Modus. ConnectionLimit schließt beide Lücken — mit automatischer Netzerkennung, Dauerbeobachtung und ehrlichen Grenzen.',
  },

  /// Zahlen, Uhrzeiten und Größenangaben. Bytes bleiben mit Punkt wie in der
  /// App; nur Fließtext folgt der Landessitte.
  locale: 'de-AT',
  decimal: ',',

  lang: {
    label: 'Sprache',
    names: { de: 'Deutsch', en: 'English' },
  },

  nav: {
    demo: 'Live-Demo',
    features: 'Funktionen',
    window: 'Das Fenster',
    terminal: 'Terminal',
    limits: 'Grenzen',
    start: 'Loslegen',
    download: 'Laden',
    progress: 'Wie weit gelesen',
  },

  download: {
    requires: 'macOS 14 oder neuer',
    architectures: 'Apple Silicon und Intel',
  },

  hero: {
    eyebrow: 'Für macOS · Swift · quelloffen',
    titleLine1: 'Sehen, wer Datenvolumen',
    titleLine2: 'verbraucht — und es ',
    titleCut: 'abdrehen',
    titleEnd: '.',
    lead:
      'macOS zeigt keinen Verbrauch pro App und hat keinen Low-Data-Modus wie iOS. ConnectionLimit schließt beide Lücken, soweit das ohne Apple-Sonderrechte geht — und sagt klar, wo die Grenze verläuft.',
    cta: 'Für macOS laden',
    ctaDemo: 'Live-Demo ansehen',
    version: 'Version',
    meta: [
      { strong: 'Kein Konto', text: 'keine Anmeldung, kein Dienst dahinter' },
      { strong: 'Keine Ortung', text: 'Netz an der Router-MAC' },
      { strong: '161 Prüfungen', text: 'eigene Prüfsuite' },
    ],
    panelNote: 'Kein Screenshot — das Menüleisten-Fenster, nachgebaut und in Bewegung.',
  },

  /// Begriffe, die App und Seite teilen. Dieselben Wörter wie in der
  /// Oberfläche — wer die Seite gelesen hat, soll die App lesen können.
  terms: {
    netHome: 'Zuhause WLAN',
    netHotspot: 'iPhone von Marco',
    free: 'frei',
    metered: 'teuer',
    tiers: ['Aus', 'Sparsam', 'Urlaub', 'Notfall'],
    tierNone: 'keine Sperren',
    tierVacation: 'Updates, Backup, Telemetrie, Medien, Cloud-Sync',
    classes: {
      browser: 'Browser',
      sync: 'Cloud-Sync',
      update: 'Updates',
      messaging: 'Messenger',
    },
    rows: {
      chrome: 'Google Chrome',
      icloud: 'iCloud Fotos',
      onedrive: 'OneDrive',
      update: 'macOS Update',
      signal: 'Signal',
    },
    today: (amount: string) => `Heute ${amount}`,
    quiet: 'gerade still',
    idle: 'still',
    active: (n: number) => `${n} aktiv`,
    activeNow: 'gerade aktiv',
    paused: 'angehalten',
    lastSeen: 'zuletzt vor 4 min',
    blocked: 'gesperrt',
    despiteBlock: 'trotz Sperre',
    despiteBlockLong: 'trotz Sperre aktiv',
    block: 'Sperren',
    unblock: 'Freigeben',
  },

  panel: {
    calloutNet: 'Dieses Netz ist als teuer eingestuft. Der Urlaubsmodus greift automatisch.',
    calloutLeak: 'Trotz Sperre aktiv: OneDrive — der Hebel greift nicht vollständig.',
    profile: 'Profil',
    automatic: 'automatisch',
    services: 'Dienste',
    blockedHead: (n: number) => `Gesperrt (${n})`,
    releaseAll: 'Alles freigeben',
  },

  demo: {
    eyebrow: 'Live-Demo',
    title: 'Vier Schritte, wie es im Urlaub wirklich läuft',
    lead:
      'Kein Video, kein Bild: die Oberfläche selbst, nachgebaut und in Bewegung. Sperren lässt sich hier auch von Hand — dann übernimmst du.',
    steps: [
      {
        title: 'Zuhause: alles läuft',
        text: 'Freies WLAN, keine Sperren. Das Werkzeug misst nur — wer Daten braucht, landet in der Liste und bleibt dort stehen.',
      },
      {
        title: 'Am Hotspot: das Netz sagt Bescheid',
        text: 'Der Router wird an seiner MAC-Adresse wiedererkannt und ist als „teuer“ eingestuft. Der Urlaubsmodus greift von selbst — ohne dass jemand daran denken muss.',
      },
      {
        title: 'Sperren greifen',
        text: 'Cloud-Sync und Updates werden angehalten. Jede Sperre bekommt eine Quittung in der Datenbank, bevor sie gesetzt wird.',
      },
      {
        title: 'Ein Durchbruch wird protokolliert',
        text: 'OneDrive bewegt trotz Sperre Daten. Zeitpunkt und Menge stehen im Protokoll — eine Sperre, die nicht hält, ist schlimmer als keine.',
      },
    ] as Card[],
    log: 'Protokoll',
    pause: '❚❚ anhalten',
    resume: '▶ weiterlaufen',
    logEmpty: 'Noch nichts protokolliert. Sperren, Freigaben und Durchbrüche stehen hier mit Zeitpunkt.',
    kinds: {
      blocked: 'gesperrt',
      released: 'freigegeben',
      attempt: 'trotz Sperre aktiv',
      info: 'Netzwechsel',
    },
    events: {
      network: 'iPhone von Marco · als teuer eingestuft → Urlaubsmodus',
      icloud: 'iCloud Fotos · Systemdienst anhalten',
      onedrive: 'OneDrive · App einfrieren',
      update: 'macOS Update · Systemdienst anhalten',
      leak: 'OneDrive · 1.4 MB seit 12 Minuten',
      manual: (name: string) => `${name} · von Hand`,
    },
    tiles: {
      today: 'Heute',
      sinceMidnight: 'seit Mitternacht',
      now: 'Gerade',
      watched: 'Beobachtet',
      inList: 'Dienste in der Liste',
      blocked: 'Gesperrt',
      leaks: (n: number) => `${n} mit Durchbruch`,
      noLeaks: 'keine Durchbrüche',
    },
  },

  features: {
    eyebrow: 'Funktionen',
    title: 'Sechs Dinge, die macOS nicht mitbringt',
    lead: 'Gebaut für die Situation, in der Volumen knapp ist: Hotspot, Roaming, Hotel-Tarif.',
    items: [
      {
        title: 'Dauerbeobachtung',
        text: 'Wer einmal Daten gebraucht hat, bleibt in der Liste — bis du zurücksetzt. Sonst könnte man genau das nicht sperren, was gerade still ist.',
      },
      {
        title: 'Durchbrüche mit Zeitpunkt',
        text: 'Fließen trotz gesetzter Sperre Daten, wird das mit Beginn, Ende und Menge protokolliert. Eine Sperre, die nicht hält, ist schlimmer als keine.',
      },
      {
        title: 'Menge über die Zeit',
        text: 'Stunden- und Tagesfenster je Dienst. Stille Fenster stehen als Null da, statt zu fehlen — sonst sähe Ruhe wie schwacher Verkehr aus.',
      },
      {
        title: 'Das Netz sagt, dass Urlaub ist',
        text: 'Jedes Netz wird an der MAC-Adresse seines Routers wiedererkannt — ohne Ortungsdienste. Am Hotspot greift der Urlaubsmodus, zuhause fällt er von selbst weg.',
      },
      {
        title: 'Profile, die du selbst festlegst',
        text: 'Jede Stufe sperrt Klassen, keine einzelnen Dienste — so greift sie auch für Dienste, die es beim Anlegen noch nicht gab. Welche Klassen das sind, bestimmst du.',
      },
      {
        title: 'Sicherheitsnetz',
        text: 'Quittung vor dem Eingriff, Aufräumen beim Start, im Zweifel freigeben. Und niemals den eigenen Prozess oder sein Terminal einfrieren.',
      },
    ] as Card[],
  },

  shots: {
    eyebrow: 'Das Fenster',
    title: 'Echte Bildschirmfotos, nichts nachgezeichnet',
    lead: 'Aufgenommen auf einem laufenden Mac. Die Zahlen sind echte Messwerte.',
    alt: (label: string) => `ConnectionLimit — Bereich ${label}`,
    /// Nur dort gesetzt, wo die Bilder nicht der Sprache der Seite entsprechen.
    note: '',
    items: [
      {
        id: 'verbrauch',
        label: 'Verbrauch',
        caption: 'Die Dauerliste. Grün heißt „bewegt gerade Daten“, rot „gesperrt“, orange „gesperrt, und trotzdem fließt etwas“.',
      },
      {
        id: 'profile',
        label: 'Profile',
        caption: 'Jede Stufe sperrt Klassen. Welche das sind, legst du hier fest — die Voreinstellung ist nur ein Vorschlag.',
      },
      {
        id: 'protokoll',
        label: 'Protokoll',
        caption: 'Wann gesperrt, wann freigegeben, wann trotz Sperre etwas durchkam. Mit Zeitpunkt und Menge.',
      },
      {
        id: 'dienste',
        label: 'Dienste',
        caption: 'Der Katalog: was das Werkzeug kennt und mit welchem Hebel es den Dienst stoppt — samt Warnung, wie grob der Hebel wirkt.',
      },
      {
        id: 'budget',
        label: 'Budget',
        caption: 'Reisebudget mit Tagesration und Hochrechnung. Nur Verbrauch in teuren Netzen zählt.',
      },
    ] as Shot[],
  },

  terminal: {
    eyebrow: 'Terminal',
    title: 'Alles, was das Fenster kann, kann auch die Kommandozeile',
    lead: 'Dieselbe Datenbank, dieselben Regeln. Wer lieber tippt, verpasst nichts.',
    programs: [
      {
        command: 'connlimit tracked',
        lines: [
          { text: 'Getrackte Dienste  ·  seit 25.08. 17:01  ·  Netz: iPhone von Marco [teuer]', tone: 'dim' },
          { text: '' },
          { text: '  DIENST                KLASSE          GESAMT     HEUTE  ZULETZT   VERLAUF 24 h', tone: 'head' },
          { text: '● Google Chrome         Browser       412.7 MB  26.4 MB  gerade    ▁▂▃▅█▆▃▂▁▁▂▃', tone: 'green' },
          { text: '● Microsoft Outlook     E-Mail        119.3 MB  12.1 MB  gerade    ▂▃▂▁▁▂▅▃▂▁▁▁', tone: 'green' },
          { text: '⚠ OneDrive              Cloud-Sync     64.0 MB   1.4 MB  gerade    ▁▁▁▂▁▁▁▂▁▁▁▁', tone: 'amber' },
          { text: '  ↳ 3× trotz Sperre aktiv · 1.4 MB · zuletzt 12:04', tone: 'dim' },
          { text: '🔒 iCloud Fotos         Cloud-Sync    180.2 MB       —  vor 8 min ▃▅▂▁▁·······', tone: 'red' },
          { text: '  macOS Update          Updates        29.0 MB       —  vor 39 min▁▁·········', tone: 'dim' },
          { text: '' },
          { text: 'Gesamt: 805.2 MB  ·  25 Dienste  ·  3 gerade aktiv', tone: 'dim' },
        ],
      },
      {
        command: 'connlimit events --attempts',
        lines: [
          { text: 'Protokoll  ·  seit 18.08. 12:04', tone: 'dim' },
          { text: '' },
          { text: '  12:04–12:19       trotz Sperre aktiv  OneDrive        1.4 MB', tone: 'amber' },
          { text: '  09:31–09:33       trotz Sperre aktiv  iCloud Fotos    240 kB', tone: 'amber' },
          { text: '  gestern 21:12     trotz Sperre aktiv  OneDrive        780 kB', tone: 'amber' },
          { text: '' },
          { text: 'Eine Sperre, durch die etwas durchkommt, ist schlimmer als keine —', tone: 'dim' },
          { text: 'weil man sich auf sie verlässt. Deshalb steht sie hier.', tone: 'dim' },
        ],
      },
      {
        command: 'connlimit profile edit sparsam update backup media',
        lines: [
          { text: '✓ Sparsam sperrt jetzt: Updates, Backup, Medien', tone: 'green' },
          { text: '   freigegeben: Apple Diagnose', tone: 'dim' },
          { text: '' },
          { text: '$ connlimit profile', tone: 'dim' },
          { text: '  ● Aus             —', tone: 'dim' },
          { text: '  ○ Sparsam         Updates, Backup, Medien  ✎', tone: 'amber' },
          { text: '  ○ Urlaubsmodus    Updates, Backup, Telemetrie, Medien, Cloud-Sync', tone: 'dim' },
          { text: '  ○ Notfall         … zusätzlich E-Mail, Browser', tone: 'dim' },
        ],
      },
    ] as TermProgram[],
  },

  honest: {
    eyebrow: 'Ehrlich gesagt',
    title: 'Was es kann — und was nicht',
    lead:
      'macOS bietet ohne Apple-Entitlement keinen Weg, einer einzelnen App nur das Netz zu entziehen. Deshalb gestaffelte Hebel — und deshalb steht hier, wo jeder aufhört.',
    canTitle: 'Das geht',
    cannotTitle: 'Das geht nicht',
    can: [
      <><b>Verbrauch pro Dienst</b> — über <code className="mono">nettop</code>, ohne Sonderrechte.</>,
      <><b>Systemdienste sauber anhalten</b> — <code className="mono">launchctl kill SIGSTOP</code>, vollständig reversibel.</>,
      <><b>Netze automatisch erkennen</b> — an der MAC-Adresse des Routers, ohne Ortungsdienste.</>,
      <><b>Budget mit Tagesration</b> — samt Hochrechnung und automatischer Eskalation.</>,
      <><b>Alles rückgängig machen</b> — Quittung vor dem Eingriff, Aufräumen beim Start.</>,
    ] as ReactNode[],
    cannot: [
      <><b>Einer App nur das Netz nehmen</b> — dafür bräuchte es einen <code className="mono">NEFilterDataProvider</code>, ein von Apple freizugebendes Entitlement und Xcode.</>,
      <><b>Abrechnungsgenaue Zahlen</b> — <code className="mono">nettop</code> ist ein Stichprobenverfahren. Prozesse, die zwischen zwei Messungen entstehen und vergehen, fehlen.</>,
      <><b>Ohne sudo alles sperren</b> — macOS-Update, iCloud und Time Machine brauchen root. Das Werkzeug sagt das ausdrücklich, statt „Urlaubsmodus aktiv“ zu behaupten.</>,
      <><b>CDN-Adressen dauerhaft sperren</b> — die weichen aus. Der PF-Hebel weiß das und schreibt es an die Zeile.</>,
    ] as ReactNode[],
    leversTitle: 'Die drei Hebel',
    leversLead: 'Für jeden Dienst wird der beste verfügbare genommen — von sauber nach grob.',
    head: { lever: 'Hebel', effect: 'Wirkung', rights: 'Rechte' },
    levers: [
      {
        name: 'Systemdienst anhalten',
        effect: <><code className="mono">launchctl kill SIGSTOP</code> — sauber, vollständig reversibel, stoppt das Volumen an der Quelle</>,
        rights: 'root',
        tone: 'amber',
      },
      {
        name: 'Ziel-Adressen sperren',
        effect: <>Eigener PF-Anchor; die App bleibt bedienbar, aber CDN-Adressen können ausweichen</>,
        rights: 'root + install-pf',
        tone: 'amber',
      },
      {
        name: 'App einfrieren',
        effect: <><code className="mono">SIGSTOP</code> — friert die <b>ganze</b> App ein, nicht nur ihr Netz. Für Sync-Clients genau richtig, für Browser grob</>,
        rights: 'keine',
        tone: 'green',
      },
    ] as { name: string; effect: ReactNode; rights: string; tone: 'amber' | 'green' }[],
  },

  start: {
    eyebrow: 'Loslegen',
    title: 'Laden, öffnen, Netz einstufen',
    lead:
      'Beim ersten Start ist auch das Heim-WLAN unbekannt. Dort ungefragt Dienste einzufrieren wäre die falsche Art Überraschung — deshalb passiert erst etwas, wenn du ein Netz einstufst.',
    product: 'ConnectionLimit für macOS',
    version: 'Version',
    download: (size: string) => `Laden (${size})`,
    copy: 'kopieren',
    copied: 'kopiert',
    steps: {
      get: {
        title: 'Laden und ablegen',
        text: 'Das Abbild öffnen und ConnectionLimit in den Ordner „Programme“ ziehen. Ein Universal-Programm für Apple Silicon und Intel.',
      } as InstallStep,
      gatekeeper: {
        title: 'Beim ersten Start: Rechtsklick › Öffnen',
        text: 'Das Programm ist nicht bei Apple notarisiert — ein Doppelklick wird deshalb zunächst abgelehnt. Über das Kontextmenü einmal „Öffnen“ wählen, danach startet es wie jedes andere.',
        code: 'xattr -d com.apple.quarantine /Applications/ConnectionLimit.app',
        codeNote: 'Wer den Weg über das Terminal bevorzugt',
      } as InstallStep,
      classify: {
        title: 'Netz einstufen',
        text: 'Solange ein Netz nicht eingestuft ist, sperrt das Werkzeug bewusst nichts. In der Menüleiste oben rechts — oder im Terminal.',
        code: 'connlimit net set current teuer',
        codeNote: 'Oder im Terminal',
      } as InstallStep,
    },
    notarized: 'Signiert mit Developer ID und bei Apple notarisiert. ',
    adhoc:
      'Nichts davon ist eine Blackbox: Das Programm ist ad hoc signiert, nicht notarisiert — genau deshalb der Umweg in Schritt 2. ',
    cli: 'Die Kommandozeile steckt im Programm; einmal verknüpfen, dann liegt sie im PATH:',
    sourceBefore: 'Wer lieber selbst baut, findet den vollständigen Quelltext samt Prüfsuite auf',
    sourceAfter: '.',
  },

  footer: {
    tagline: 'Sehen, wer Datenvolumen verbraucht — und es abdrehen.',
    made: 'Gebaut für Hotspot, Roaming und Hotel-Tarif.',
  },
}

export type Dict = typeof de
