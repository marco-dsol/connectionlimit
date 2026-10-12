import Foundation
import ConnLimitCore

// MARK: - net

func cmdNet(_ args: Args) throws {
    let app = try App()
    let sub = args[1] ?? "list"

    switch sub {
    case "list":
        let (current, _) = try app.refreshNetwork()
        let networks = try app.store.allNetworks()
        print(Term.bold(L("Bekannte Netze")))
        print()
        print(Term.dim(Term.pad("", 3) + Term.pad("ID", 18) + Term.pad(L("NAME"), 26)
                     + Term.pad(L("KLASSE"), 12) + L("ZULETZT")))
        for n in networks {
            let marker = n.identity.id == current.id ? Term.green("▸") : " "
            let cls = n.networkClass
            let colored: String = {
                switch cls {
                case .free:    return Term.green(cls.displayName)
                case .metered: return Term.red(cls.displayName)
                case .limited: return Term.yellow(cls.displayName)
                case .unknown: return Term.dim(cls.displayName)
                }
            }()
            print(Term.pad(" \(marker) ", 3) + Term.pad(Term.dim(n.identity.id), 18)
                + Term.fit(n.identity.displayLabel, 26) + Term.pad(colored, 12)
                + Term.dim(DisplayTime.dayAndTime(n.lastSeen)))
        }
        print()
        print(Term.dim(L("connlimit net set <id|current> <frei|teuer|begrenzt>")))
        print(Term.dim(L("connlimit net name <id|current> \"Hotel WLAN\"")))

    case "set":
        guard let target = args[2], let clsText = args[3],
              let cls = Parse.networkClass(clsText) else {
            throw CLIError.usage(L("connlimit net set <id|current> <frei|teuer|begrenzt>"))
        }
        let id = try resolveNetworkId(target, app: app)
        try app.store.setNetworkClass(cls, for: id)
        print(Term.green("✓ ") + L("Netz %@ ist jetzt %@", id, Term.bold(cls.displayName)))
        if cls.countsAgainstBudget {
            print(Term.dim("   " + L("Verbrauch in diesem Netz zählt gegen das Budget.")))
        }
        if app.store.policyState.manualTier == nil {
            print(Term.dim("   " + L("Die App wendet das passende Profil beim nächsten Abgleich an (spätestens nach 30 s).")))
        }

    case "name":
        guard let target = args[2], let label = args[3] else {
            throw CLIError.usage(L("connlimit net name <id|current> \"Name\""))
        }
        let id = try resolveNetworkId(target, app: app)
        try app.store.setNetworkLabel(label, for: id)
        print(Term.green("✓ ") + L("Netz %@ heißt jetzt %@", id, label))

    default:
        throw CLIError.usage("connlimit net [list|set|name]")
    }
}

private func resolveNetworkId(_ target: String, app: App) throws -> String {
    if target == "current" || target == "aktuell" {
        return try app.refreshNetwork().identity.id
    }
    return target
}

// MARK: - budget

func cmdBudget(_ args: Args) throws {
    let app = try App()
    let sub = args[1]

    switch sub {
    case nil, "show":
        guard let status = try app.budget.status() else {
            print(Term.dim(L("Kein Budget gesetzt.")))
            print(Term.dim("connlimit budget set 5GB --until 2026-09-06"))
            return
        }
        // Beschriftungen gleich breit, damit die Werte in jeder Sprache eine
        // Spalte bilden.
        let rows: [(String, String)] = [
            (L("Volumen"), ByteFormat.short(status.budget.totalBytes)),
            (L("Verbraucht"), ByteFormat.short(status.usedBytes)),
            (L("Übrig"), Term.bold(ByteFormat.short(status.remainingBytes))
                + Term.dim("  (\(Int(status.remainingFraction * 100)) %)")),
            (L("Restlaufzeit"), L("%@ Tage", String(format: "%.1f", status.remainingDays))),
            (L("Tagesbudget"), ByteFormat.short(status.dailyAllowance)),
            (L("Heute"), ByteFormat.short(status.usedTodayBytes)
                + Term.dim("  " + L("Hochrechnung %@", ByteFormat.short(status.projectedToday)))),
        ]
        let lightText: String
        switch status.light {
        case .green:  lightText = Term.green("● " + status.light.text)
        case .yellow: lightText = Term.yellow("● " + status.light.text)
        case .red:    lightText = Term.red("● " + status.light.text)
        }
        let width = (rows.map(\.0.count) + [L("Status").count]).max()! + 2
        print(Term.bold(status.budget.label))
        for (label, value) in rows { print("  " + Term.pad(label, width) + value) }
        print("  " + Term.pad(L("Status"), width) + lightText)
        print()
        print(Term.dim(L("Nur Traffic in teuren oder begrenzten Netzen zählt.")))

    case "set":
        guard let volumeText = args[2], let bytes = ByteFormat.parse(volumeText), bytes > 0 else {
            throw CLIError.usage(L("connlimit budget set <5GB> --until <2026-09-06> [--label \"Italien\"]"))
        }
        guard let untilText = args.value("until"), let untilDay = Parse.date(untilText) else {
            throw CLIError.usage(L("--until <YYYY-MM-DD> fehlt oder ist unlesbar"))
        }
        // Ein reines Datum meint den ganzen Tag, nicht dessen Mitternacht —
        // sonst fehlte der letzte Reisetag im Budget.
        let until = untilText.contains(":") ? untilDay
            : (Calendar.current.date(byAdding: .day, value: 1, to: untilDay) ?? untilDay)
                .addingTimeInterval(-1)
        let from = args.value("from").flatMap(Parse.date) ?? Date()
        guard until > from else {
            throw CLIError.usage(L("Das Enddatum liegt vor dem Beginn."))
        }
        let budget = Budget(totalBytes: bytes, startsAt: from, endsAt: until,
                            label: args.value("label") ?? L("Reise"))
        try app.store.saveBudget(budget)
        print(Term.green("✓ ") + L("Budget: %@ bis %@", ByteFormat.short(bytes), untilText))
        if let status = try app.budget.status() {
            print(Term.dim("   " + L("Tagesbudget: %@", ByteFormat.short(status.dailyAllowance))))
        }

    case "clear":
        try app.store.saveBudget(nil)
        print(Term.green("✓ ") + L("Budget gelöscht"))

    default:
        throw CLIError.usage("connlimit budget [show|set|clear]")
    }
}

// MARK: - except

func cmdExcept(_ args: Args) throws {
    let app = try App()
    guard let sub = args[1] else {
        let state = app.store.policyState
        print(Term.bold(L("Ausnahmen")))
        print("  " + Term.pad(L("Immer erlaubt: "), 17) + (state.alwaysAllow.isEmpty
            ? Term.dim("—") : state.alwaysAllow.sorted().joined(separator: ", ")))
        print("  " + Term.pad(L("Immer gesperrt: "), 17) + (state.alwaysBlock.isEmpty
            ? Term.dim("—") : state.alwaysBlock.sorted().joined(separator: ", ")))
        print()
        print(Term.dim(L("connlimit except allow <dienst>   — auch im Urlaubsmodus erlauben")))
        print(Term.dim(L("connlimit except block <dienst>   — immer sperren")))
        print(Term.dim(L("connlimit except clear <dienst>   — Ausnahme entfernen")))
        return
    }
    guard let query = args[2] else {
        throw CLIError.usage(L("connlimit except <allow|block|clear> <dienst>"))
    }
    let service = try app.service(matching: query)
    var state = app.store.policyState

    switch sub {
    case "allow":
        state.alwaysAllow.insert(service.id)
        state.alwaysBlock.remove(service.id)
        print(Term.green("✓ ") + L("%@ bleibt immer erlaubt", service.displayName))
    case "block":
        guard service.isBlockable else {
            throw CLIError.usage(L("%@ ist systemkritisch und kann nicht gesperrt werden.", service.displayName))
        }
        state.alwaysBlock.insert(service.id)
        state.alwaysAllow.remove(service.id)
        print(Term.green("✓ ") + L("%@ ist immer gesperrt", service.displayName))
    case "clear":
        state.alwaysAllow.remove(service.id)
        state.alwaysBlock.remove(service.id)
        print(Term.green("✓ ") + L("Ausnahme für %@ entfernt", service.displayName))
    default:
        throw CLIError.usage(L("connlimit except <allow|block|clear> <dienst>"))
    }
    try app.store.savePolicyState(state)
}

// MARK: - run

func cmdRun(_ args: Args) throws {
    var config = Agent.Config()
    config.readOnly = args.flag("read-only") || args.has("read-only")
    config.verbose = args.flag("v") || args.has("verbose")
    if let interval = args.value("interval").flatMap(Double.init) {
        config.sampleInterval = interval
    }

    let app = try App(config: config)
    print(Term.bold(L("connlimit läuft"))
        + Term.dim(config.readOnly ? "  " + L("(nur messen, keine Sperren)") : "")
        + Term.dim("  ·  " + L("Strg-C zum Beenden")))

    installShutdownHandler(agent: app.agent)
    try app.agent.run()
}

private var shutdownAgent: Agent?

private func installShutdownHandler(agent: Agent) {
    shutdownAgent = agent
    // signal() darf nur async-signal-sichere Funktionen aufrufen. Deshalb hier
    // nur ein Flag setzen — das Aufräumen erledigt die Schleife selbst.
    for sig in [SIGINT, SIGTERM] {
        signal(sig) { _ in shutdownAgent?.stop() }
    }
}

// MARK: - doctor

func cmdDoctor(_ args: Args) throws {
    print(Term.bold(L("Systemprüfung")))
    print()

    func check(_ label: String, _ ok: Bool, _ detail: String) {
        let mark = ok ? Term.green("✓") : Term.yellow("○")
        print("  \(mark) " + Term.pad(label, 26) + Term.dim(detail))
    }

    let nettopOK = FileManager.default.isExecutableFile(atPath: "/usr/bin/nettop")
    check("nettop", nettopOK, nettopOK ? L("Messung verfügbar") : L("fehlt — ohne geht nichts"))

    let app = try App()
    let (identity, cls) = try app.refreshNetwork()
    check(L("Netzerkennung"), !identity.isOffline,
          identity.isOffline ? L("offline") : "\(identity.displayLabel) [\(cls.displayName)]")
    check("Gateway-MAC", identity.gatewayMAC != nil,
          identity.gatewayMAC ?? L("nicht ermittelbar — Netz-ID weniger stabil"))

    check(L("Datenbank"), true, Store.defaultPath)

    check("root", Shell.isRoot,
          Shell.isRoot ? L("launchd- und PF-Hebel verfügbar")
                       : L("ohne sudo nur der Hebel 'App einfrieren'"))

    check("PF-Anchor", PFAnchor.isInstalled,
          PFAnchor.isInstalled ? L("installiert")
                               : L("nicht installiert — 'sudo connlimit install-pf' für Domain-Sperren"))

    let running = ProcessLookup.running().count
    check(L("Prozessliste"), running > 0, L("%@ Prozesse sichtbar", running))

    let receipts = try app.store.openReceipts()
    check(L("Offene Sperren"), receipts.isEmpty,
          receipts.isEmpty ? L("keine") : L("%@ — 'connlimit status' zeigt sie", receipts.count))

    check(L("Sprache"), true, L10n.language.nativeName
          + Term.dim("  ·  connlimit lang <de|en|auto>"))

    print()
    print(Term.dim(L("Was welcher Hebel wirklich tut, steht in der README.")))
}

// MARK: - PF-Installation

func cmdInstallPF(_ args: Args) throws {
    guard Shell.isRoot else {
        throw CLIError.usage(L("Braucht root: %@", "sudo connlimit install-pf"))
    }
    guard !PFAnchor.isInstalled else {
        print(Term.dim(L("PF-Anchor ist bereits installiert.")))
        return
    }
    print(L("Fügt %@ zu /etc/pf.conf hinzu.", PFAnchor.anchorLine))
    print(Term.dim(L("Eine Sicherung wird unter /etc/pf.conf.connlimit-backup abgelegt.")))
    try PFAnchor.install()
    print(Term.green("✓ ") + L("PF-Anchor installiert und Regelsatz neu geladen"))
}

func cmdUninstallPF(_ args: Args) throws {
    guard Shell.isRoot else {
        throw CLIError.usage(L("Braucht root: %@", "sudo connlimit uninstall-pf"))
    }
    try PFAnchor.uninstall()
    print(Term.green("✓ ") + L("PF-Anchor entfernt, alle Regeln geleert"))
}

// MARK: - lang

/// `connlimit lang [de|en|auto]` — dieselbe Einstellung wie im Menü der App.
func cmdLang(_ args: Args) throws {
    guard let arg = args[1]?.lowercased() else {
        let preference = L10n.storedPreference
        print(L("Sprache: %@", L10n.language.nativeName)
            + (preference == .system ? Term.dim("  (" + L("wie macOS") + ")") : ""))
        print(Term.dim("connlimit lang <de|en|auto>"))
        return
    }
    let preference: LanguagePreference
    switch arg {
    case "de", "deutsch", "german":  preference = .de
    case "en", "englisch", "english": preference = .en
    case "auto", "system":            preference = .system
    default: throw CLIError.usage("connlimit lang <de|en|auto>")
    }
    L10n.setPreference(preference)
    print(Term.green("✓ ") + L("Sprache: %@", L10n.language.nativeName)
        + Term.dim("  ·  " + L("gilt für App und Terminal")))
}
