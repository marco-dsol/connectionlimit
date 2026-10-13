import type { ReactNode } from 'react'
import type { Dict } from './de'
import { COMPANY, LEGAL_UPDATED, PROJECT_EMAIL } from '../lib/company'
import { GITHUB_URL } from '../lib/download'

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
    demo: 'Overview',
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
    eyebrow: 'Overview',
    title: 'Four steps: how it really goes on holiday',
    lead:
      'The app’s interface, rebuilt and in motion — not a screenshot. You can block things by hand here too — then you take over.',
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
    project: 'A project by',
    dsolUrl: `${COMPANY.dsol}/en/`,
    madeWith: 'Made with ❤️ and AI in Tyrol by',
  },

  spot: {
    cta: 'Watch the video',
    length: '1:06',
    title: 'ConnectionLimit on video',
    ai: 'Voice-over and music are AI-created.',
    fallback: 'Your browser cannot play this video.',
  },

  stats: {
    title: 'May I count your visit?',
    text: 'I’d like to collect anonymous visitor statistics – with Umami on my own server, without cookies and without sharing anything with third parties.',
    privacy: 'Privacy policy',
    deny: 'No thanks',
    accept: 'Yes, sure',
    settings: 'Statistics settings',
  },

  legal: {
    title: 'Legal',
    close: 'Close',
    links: { impressum: 'Legal notice', haftung: 'Disclaimer', datenschutz: 'Privacy' },
    updated: `Last updated: ${LEGAL_UPDATED.en}`,
    impressum: (
      <>
        <p>
          ConnectionLimit is a project of {COMPANY.name} ({COMPANY.short}) under the{' '}
          <a href={`${COMPANY.dsol}/en/`}>DSOL</a> brand (Digital Solutions). This website is operated by{' '}
          {COMPANY.name}, which is responsible for its content.
        </p>
        <p>
          <b>{COMPANY.name}</b><br />
          Owner: {COMPANY.owner}<br />
          Software development & IT consulting<br />
          {COMPANY.street}, {COMPANY.city}, Tyrol, Austria
        </p>
        <p>
          Email: <a href={`mailto:${PROJECT_EMAIL}`}>{PROJECT_EMAIL}</a> · <a href={`mailto:${COMPANY.email}`}>{COMPANY.email}</a><br />
          Phone: <a href={COMPANY.phoneHref}>{COMPANY.phone}</a><br />
          Web: <a href={`${COMPANY.dsol}/en/`}>www.dsol.at</a> · <a href={COMPANY.mitsol}>www.mitsol.at</a>
        </p>
        <p>
          VAT ID: {COMPANY.uid}<br />
          Company register number: {COMPANY.register}<br />
          Member of the Tyrolean Chamber of Commerce, <a href={COMPANY.wko}>WKÖ company listing</a><br />
          Supervisory authority: Bezirkshauptmannschaft Innsbruck (district authority)<br />
          Applicable regulations: Austrian Trade Regulation Act (Gewerbeordnung), available at{' '}
          <a href="https://www.ris.bka.gv.at">www.ris.bka.gv.at</a>
        </p>
        <p>
          Disclosure under § 25 of the Austrian Media Act: the media owner is {COMPANY.name}. This website provides
          information about the ConnectionLimit software.
        </p>
        <p>
          Bugs and suggestions for the app are welcome as an <a href={`${GITHUB_URL}/issues`}>issue on GitHub</a> or
          at <a href={`mailto:${PROJECT_EMAIL}`}>{PROJECT_EMAIL}</a>. Please send complaints to <a href={`mailto:${COMPANY.email}`}>{COMPANY.email}</a>.
        </p>
      </>
    ) as ReactNode,
    haftung: (
      <>
        <p>
          <b>Software without warranty.</b> ConnectionLimit is free and open source and is provided as is under the{' '}
          <a href={`${GITHUB_URL}/blob/main/LICENSE`}>MIT License</a> — without any warranty of function,
          freedom from defects or fitness for a particular purpose. The app intervenes in running programs and
          system services and can set rules in the macOS packet filter firewall; you use it at your own risk. To the
          extent permitted by law, we are not liable for damage or costs arising from its use — such as paused
          services, delayed syncing or data used despite a block.
        </p>
        <p>
          <b>Measurements are estimates.</b> Usage figures are based on samples from{' '}
          <code className="mono">nettop</code> and are not billing-accurate. Only your mobile carrier’s bill counts.
        </p>
        <p>
          <b>Content of this website.</b> The content has been prepared with care, but we cannot guarantee that it
          is accurate, complete or up to date. The operators of linked external websites are solely responsible for
          their content.
        </p>
        <p>
          <b>Built with AI.</b> ConnectionLimit — the app, this website and the video — was created with the help of
          AI. The voice-over and music in the video are AI-created.
        </p>
        <p>
          <b>Trademarks.</b> ConnectionLimit is an independent project and is not affiliated with Apple or any other
          provider mentioned. macOS, iCloud and Time Machine are trademarks of Apple Inc.; OneDrive, Outlook,
          Dropbox, Google Chrome, Signal and all other names mentioned belong to their respective owners and are used
          for identification only.
        </p>
        <p>
          <b>Copyright.</b> The source code is licensed under the MIT License and may be used freely within its
          terms. All other content of this website — text, graphics and video — is protected by Austrian copyright
          law. The Inter and JetBrains Mono typefaces are licensed under the SIL Open Font License.
        </p>
      </>
    ) as ReactNode,
    datenschutz: (
      <>
        <p>
          The controller is {COMPANY.name}, {COMPANY.owner}, {COMPANY.street}, {COMPANY.city}, Austria,{' '}
          <a href={`mailto:${COMPANY.email}`}>{COMPANY.email}</a>.
        </p>
        <p>
          <b>The app collects nothing.</b> ConnectionLimit runs entirely on your Mac: no account, no telemetry, no
          connection to our servers. Measurements, recognised networks and the log are kept in a database on your Mac
          (<code className="mono">~/Library/Application Support/at.mitsol.connectionlimit</code>) and never leave it.
        </p>
        <p>
          <b>No cookies, no ads.</b> This website sets no cookies and shows no ads. Fonts, video and analytics are
          served from our own server; no third-party content is embedded.
        </p>
        <p>
          <b>Anonymous visitor statistics (only with your consent).</b> If you agree, we use{' '}
          <a href="https://umami.is">Umami</a> to count page views anonymously, along with how often the video is
          played and the app downloaded. Umami runs on our own server (umami.dsol.at, Hetzner, Germany), sets no
          cookies, stores no full IP addresses and builds no profiles across websites. It records the page visited,
          referring page, browser, operating system, device type, screen size, language and approximate country. The
          legal basis is your consent (Art. 6(1)(a) GDPR), which you can withdraw at any time under{' '}
          <a href="#statistik">Statistics settings</a>. Without your consent, the analytics script is not loaded at
          all.
        </p>
        <p>
          <b>Server logs.</b> When you visit, the web server processes technically necessary data — IP address,
          time, requested address and browser identifier — to deliver the site and keep it secure (Art. 6(1)(f)
          GDPR). The server is located in the European Union, at Hetzner Online GmbH in Nuremberg, Germany.
        </p>
        <p>
          <b>Storage in your browser.</b> The site only remembers your language and your analytics choice in your
          browser (localStorage). Neither leaves your device, and both can be deleted at any time in your browser
          settings.
        </p>
        <p>
          <b>Download and source code on GitHub.</b> The app package and the source code are hosted on GitHub. If
          you follow one of these links, your browser connects to GitHub, Inc. (USA) and your IP address is
          transmitted there. GitHub’s{' '}
          <a href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement">
            privacy statement
          </a>{' '}
          applies.
        </p>
        <p>
          <b>Contact by email.</b> If you write to us, we store your message and address to handle your request and
          delete them after six months at the latest, unless we are legally required to keep them.
        </p>
        <p>
          <b>Your rights.</b> You have the right of access, rectification, erasure, restriction of processing, data
          portability and objection. To exercise them, contact{' '}
          <a href={`mailto:${COMPANY.email}`}>{COMPANY.email}</a>. You can lodge a complaint with the Austrian Data
          Protection Authority (<a href="https://www.dsb.gv.at">www.dsb.gv.at</a>).
        </p>
      </>
    ) as ReactNode,
  },
}
