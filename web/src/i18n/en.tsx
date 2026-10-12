import type { Dict } from './de'

/// Das englische Wörterbuch. Fachbegriffe wie in der englischen App-Fassung:
/// metered, Frugal, Vacation, active despite block, lever.

export const en: Dict = {
  meta: {
    title: 'ConnectionLimit — see who is burning through your data. And cut them off.',
    description:
      'macOS shows no per-app data usage and has no Low Data Mode. ConnectionLimit closes both gaps — with automatic network detection, persistent tracking and honest limits.',
  },

  locale: 'en-GB',
  decimal: '.',

  lang: {
    label: 'Language',
    names: { de: 'Deutsch', en: 'English' },
  },

  nav: {
    demo: 'Live demo',
    features: 'Features',
    window: 'The window',
    terminal: 'Terminal',
    limits: 'Limits',
    start: 'Get started',
    download: 'Download',
    progress: 'Reading progress',
  },

  download: {
    requires: 'macOS 14 or later',
    architectures: 'Apple Silicon and Intel',
  },

  hero: {
    eyebrow: 'For macOS · Swift · open source',
    titleLine1: 'See who burns',
    titleLine2: 'through your data — and ',
    titleCut: 'cut them off',
    titleEnd: '.',
    lead:
      'macOS shows no per-app data usage and has no Low Data Mode like iOS. ConnectionLimit closes both gaps as far as that is possible without special Apple entitlements — and says plainly where the limit runs.',
    cta: 'Download for macOS',
    ctaDemo: 'See the live demo',
    version: 'Version',
    meta: [
      { strong: 'No account', text: 'no sign-up, no service behind it' },
      { strong: 'No location', text: 'networks known by router MAC' },
      { strong: '161 checks', text: 'its own test suite' },
    ],
    panelNote: 'Not a screenshot — the menu bar window, rebuilt and in motion.',
  },

  terms: {
    netHome: 'Home Wi-Fi',
    netHotspot: "Marco's iPhone",
    free: 'free',
    metered: 'metered',
    tiers: ['Off', 'Frugal', 'Vacation', 'Emergency'],
    tierNone: 'no blocks',
    tierVacation: 'Updates, Backup, Telemetry, Media, Cloud sync',
    classes: {
      browser: 'Browser',
      sync: 'Cloud sync',
      update: 'Updates',
      messaging: 'Messaging',
    },
    rows: {
      chrome: 'Google Chrome',
      icloud: 'iCloud Photos',
      onedrive: 'OneDrive',
      update: 'macOS Update',
      signal: 'Signal',
    },
    today: (amount: string) => `Today ${amount}`,
    quiet: 'idle right now',
    idle: 'idle',
    active: (n: number) => `${n} active`,
    activeNow: 'active now',
    paused: 'paused',
    lastSeen: 'last seen 4 min ago',
    blocked: 'blocked',
    despiteBlock: 'despite block',
    despiteBlockLong: 'active despite block',
    block: 'Block',
    unblock: 'Unblock',
  },

  panel: {
    calloutNet: 'This network is classified as metered. Vacation mode kicks in automatically.',
    calloutLeak: 'Active despite block: OneDrive — the lever is not fully holding.',
    profile: 'Profile',
    automatic: 'automatic',
    services: 'Services',
    blockedHead: (n: number) => `Blocked (${n})`,
    releaseAll: 'Unblock all',
  },

  demo: {
    eyebrow: 'Live demo',
    title: 'Four steps: how it really goes on holiday',
    lead:
      'No video, no picture: the interface itself, rebuilt and in motion. You can block things by hand here too — then you take over.',
    steps: [
      {
        title: 'At home: everything runs',
        text: 'Free Wi-Fi, no blocks. The tool only measures — whoever uses data lands in the list and stays there.',
      },
      {
        title: 'At the hotspot: the network tells it',
        text: 'The router is recognised by its MAC address and is classified as “metered”. Vacation mode kicks in on its own — nobody has to remember.',
      },
      {
        title: 'Blocks take hold',
        text: 'Cloud sync and updates are paused. Every block gets a receipt in the database before it is set.',
      },
      {
        title: 'A leak gets logged',
        text: 'OneDrive moves data despite the block. Time and volume go into the log — a block that does not hold is worse than none.',
      },
    ],
    log: 'Log',
    pause: '❚❚ pause',
    resume: '▶ resume',
    logEmpty: 'Nothing logged yet. Blocks, unblocks and leaks show up here with a timestamp.',
    kinds: {
      blocked: 'blocked',
      released: 'unblocked',
      attempt: 'active despite block',
      info: 'network change',
    },
    events: {
      network: "Marco's iPhone · classified as metered → Vacation",
      icloud: 'iCloud Photos · Pause system service',
      onedrive: 'OneDrive · Freeze app',
      update: 'macOS Update · Pause system service',
      leak: 'OneDrive · 1.4 MB over 12 minutes',
      manual: (name: string) => `${name} · by hand`,
    },
    tiles: {
      today: 'Today',
      sinceMidnight: 'since midnight',
      now: 'Right now',
      watched: 'Tracked',
      inList: 'services in the list',
      blocked: 'Blocked',
      leaks: (n: number) => `${n} with a leak`,
      noLeaks: 'no leaks',
    },
  },

  features: {
    eyebrow: 'Features',
    title: 'Six things macOS does not come with',
    lead: 'Built for the moment data is scarce: hotspot, roaming, hotel tariff.',
    items: [
      {
        title: 'Persistent tracking',
        text: 'Whatever once used data stays in the list — until you reset it. Otherwise you could never block the very thing that happens to be quiet right now.',
      },
      {
        title: 'Leaks with a timestamp',
        text: 'If data flows despite a block, it is logged with start, end and volume. A block that does not hold is worse than none.',
      },
      {
        title: 'Volume over time',
        text: 'Hourly and daily windows per service. Quiet windows show as zero instead of going missing — otherwise silence would look like light traffic.',
      },
      {
        title: 'The network says you are travelling',
        text: 'Every network is recognised by its router’s MAC address — no location services. At the hotspot Vacation mode kicks in; at home it falls away on its own.',
      },
      {
        title: 'Profiles you define',
        text: 'Each tier blocks classes, not individual services — so it also covers services that did not exist when it was set up. Which classes, you decide.',
      },
      {
        title: 'Safety net',
        text: 'Receipt before every intervention, clean-up at launch, unblock when in doubt. And never freeze its own process or the terminal it runs in.',
      },
    ],
  },

  shots: {
    eyebrow: 'The window',
    title: 'Real screenshots, nothing redrawn',
    lead: 'Captured on a running Mac. The numbers are real measurements.',
    alt: (label: string) => `ConnectionLimit — ${label} section`,
    note: 'The screenshots show the German interface — the app speaks English too.',
    items: [
      {
        id: 'verbrauch',
        label: 'Usage',
        caption: 'The persistent list. Green means “moving data right now”, red “blocked”, amber “blocked, and still something flows”.',
      },
      {
        id: 'profile',
        label: 'Profiles',
        caption: 'Each tier blocks classes. Which ones is up to you — the default is only a suggestion.',
      },
      {
        id: 'protokoll',
        label: 'Log',
        caption: 'When something was blocked, when unblocked, and when data got through despite a block. With time and volume.',
      },
      {
        id: 'dienste',
        label: 'Services',
        caption: 'The catalogue: what the tool knows and which lever stops each service — including a warning about how blunt that lever is.',
      },
      {
        id: 'budget',
        label: 'Budget',
        caption: 'Travel budget with a daily allowance and a projection. Only usage on metered networks counts.',
      },
    ],
  },

  terminal: {
    eyebrow: 'Terminal',
    title: 'Everything the window can do, the command line can too',
    lead: 'Same database, same rules. If you would rather type, you miss nothing.',
    programs: [
      {
        command: 'connlimit tracked',
        lines: [
          { text: "Tracked services  ·  since Aug 25 17:01  ·  Network: Marco's iPhone [metered]", tone: 'dim' },
          { text: '' },
          { text: '  SERVICE               CLASS            TOTAL    TODAY  LAST      HISTORY 24 h', tone: 'head' },
          { text: '● Google Chrome         Browser       412.7 MB  26.4 MB  now       ▁▂▃▅█▆▃▂▁▁▂▃', tone: 'green' },
          { text: '● Microsoft Outlook     Mail          119.3 MB  12.1 MB  now       ▂▃▂▁▁▂▅▃▂▁▁▁', tone: 'green' },
          { text: '⚠ OneDrive              Cloud sync     64.0 MB   1.4 MB  now       ▁▁▁▂▁▁▁▂▁▁▁▁', tone: 'amber' },
          { text: '  ↳ 3× active despite block · 1.4 MB · last 12:04', tone: 'dim' },
          { text: '🔒 iCloud Photos        Cloud sync    180.2 MB        —  8 min ago ▃▅▂▁▁·······', tone: 'red' },
          { text: '  macOS Update          Updates        29.0 MB        —  39 min ago▁▁·········', tone: 'dim' },
          { text: '' },
          { text: 'Total: 805.2 MB  ·  25 services  ·  3 active now', tone: 'dim' },
        ],
      },
      {
        command: 'connlimit events --attempts',
        lines: [
          { text: 'Log  ·  since Aug 18 12:04', tone: 'dim' },
          { text: '' },
          { text: '  12:04–12:19       active despite block    OneDrive        1.4 MB', tone: 'amber' },
          { text: '  09:31–09:33       active despite block    iCloud Photos   240 kB', tone: 'amber' },
          { text: '  yesterday 21:12   active despite block    OneDrive        780 kB', tone: 'amber' },
          { text: '' },
          { text: 'A block that lets something through is worse than none —', tone: 'dim' },
          { text: 'because you rely on it. That is why it shows up here.', tone: 'dim' },
        ],
      },
      {
        command: 'connlimit profile edit frugal update backup media',
        lines: [
          { text: '✓ Frugal now blocks: Updates, Backup, Media', tone: 'green' },
          { text: '   unblocked: Apple Diagnostics', tone: 'dim' },
          { text: '' },
          { text: '$ connlimit profile', tone: 'dim' },
          { text: '  ● Off             —', tone: 'dim' },
          { text: '  ○ Frugal          Updates, Backup, Media  ✎', tone: 'amber' },
          { text: '  ○ Vacation        Updates, Backup, Telemetry, Media, Cloud sync', tone: 'dim' },
          { text: '  ○ Emergency       … plus Mail, Browser', tone: 'dim' },
        ],
      },
    ],
  },

  honest: {
    eyebrow: 'Honestly',
    title: 'What it can do — and what it can’t',
    lead:
      'Without an Apple entitlement, macOS offers no way to take the network away from a single app alone. Hence a ladder of levers — and hence this section, saying where each one stops.',
    canTitle: 'What works',
    cannotTitle: 'What doesn’t',
    can: [
      <><b>Usage per service</b> — via <code className="mono">nettop</code>, no special rights.</>,
      <><b>Pause system services cleanly</b> — <code className="mono">launchctl kill SIGSTOP</code>, fully reversible.</>,
      <><b>Recognise networks automatically</b> — by the router’s MAC address, no location services.</>,
      <><b>Budget with a daily allowance</b> — with projection and automatic escalation.</>,
      <><b>Undo everything</b> — receipt before the intervention, clean-up at launch.</>,
    ],
    cannot: [
      <><b>Take only the network from an app</b> — that would need a <code className="mono">NEFilterDataProvider</code>, an entitlement Apple has to grant, and Xcode.</>,
      <><b>Billing-accurate numbers</b> — <code className="mono">nettop</code> is sampling. Processes that start and end between two samples are missed.</>,
      <><b>Block everything without sudo</b> — macOS updates, iCloud and Time Machine need root. The tool says so explicitly instead of claiming “Vacation active”.</>,
      <><b>Block CDN addresses for good</b> — they move. The PF lever knows this and says so right on the row.</>,
    ],
    leversTitle: 'The three levers',
    leversLead: 'Each service gets the best one available — from clean to blunt.',
    head: { lever: 'Lever', effect: 'Effect', rights: 'Rights' },
    levers: [
      {
        name: 'Pause system service',
        effect: <><code className="mono">launchctl kill SIGSTOP</code> — clean, fully reversible, stops the volume at the source</>,
        rights: 'root',
        tone: 'amber',
      },
      {
        name: 'Block destination addresses',
        effect: <>Its own PF anchor; the app stays usable, but CDN addresses can dodge it</>,
        rights: 'root + install-pf',
        tone: 'amber',
      },
      {
        name: 'Freeze app',
        effect: <><code className="mono">SIGSTOP</code> — freezes the <b>whole</b> app, not just its network. Exactly right for sync clients, blunt for browsers</>,
        rights: 'none',
        tone: 'green',
      },
    ],
  },

  start: {
    eyebrow: 'Get started',
    title: 'Download, open, classify the network',
    lead:
      'On first launch even your home Wi-Fi is unknown. Freezing services there unasked would be the wrong kind of surprise — so nothing happens until you classify a network.',
    product: 'ConnectionLimit for macOS',
    version: 'Version',
    download: (size: string) => `Download (${size})`,
    copy: 'copy',
    copied: 'copied',
    steps: {
      get: {
        title: 'Download and drop in',
        text: 'Open the disk image and drag ConnectionLimit into Applications. One universal app for Apple Silicon and Intel.',
      },
      gatekeeper: {
        title: 'First launch: right-click › Open',
        text: 'The app is not notarised by Apple — so a double-click is refused at first. Choose “Open” once from the context menu; after that it launches like any other app.',
        code: 'xattr -d com.apple.quarantine /Applications/ConnectionLimit.app',
        codeNote: 'If you prefer the terminal',
      },
      classify: {
        title: 'Classify the network',
        text: 'As long as a network is unclassified, the tool deliberately blocks nothing. Do it in the menu bar, top right — or in the terminal.',
        code: 'connlimit net set current metered',
        codeNote: 'Or in the terminal',
      },
    },
    notarized: 'Signed with a Developer ID and notarised by Apple. ',
    adhoc:
      'None of this is a black box: the app is ad-hoc signed, not notarised — which is exactly why step 2 takes a detour. ',
    cli: 'The command line ships inside the app; link it once and it is on your PATH:',
    sourceBefore: 'If you would rather build it yourself, the full source including the test suite is on',
    sourceAfter: '.',
  },

  footer: {
    tagline: 'See who is burning through your data — and cut them off.',
    made: 'Built for hotspots, roaming and hotel tariffs.',
  },
}
