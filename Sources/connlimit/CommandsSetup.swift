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
        print(Term.bold("Bekannte Netze"))
        print()
        print(Term.dim(Term.pad("", 3) + Term.pad("ID", 18) + Term.pad("NAME", 26)
                     + Term.pad("KLASSE", 12) + "ZULETZT"))
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
                + Term.pad(n.identity.label, 26) + Term.pad(colored, 12)
                + Term.dim(shortDate(n.lastSeen)))
        }
        print()
        print(Term.dim("connlimit net set <id|current> <frei|teuer|begrenzt>"))
        print(Term.dim("connlimit net name <id|current> \"Hotel WLAN\""))

    case "set":
        guard let target = args[2], let clsText = args[3],
              let cls = Parse.networkClass(clsText) else {
            throw CLIError.usage("connlimit net set <id|current> <frei|teuer|begrenzt>")
        }
        let id = try resolveNetworkId(target, app: app)
        try app.store.setNetworkClass(cls, for: id)
        print(Term.green("✓ ") + "Netz \(id) ist jetzt " + Term.bold(cls.displayName))
        if cls.countsAgainstBudget {
            print(Term.dim("   Verbrauch in diesem Netz zählt gegen das Budget."))
        }

    case "name":
        guard let target = args[2], let label = args[3] else {
            throw CLIError.usage("connlimit net name <id|current> \"Name\"")
        }
        let id = try resolveNetworkId(target, app: app)
        try app.store.setNetworkLabel(label, for: id)
        print(Term.green("✓ ") + "Netz \(id) heißt jetzt \(label)")

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

private func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "dd.MM. HH:mm"
    return f.string(from: date)
}

// MARK: - budget

func cmdBudget(_ args: Args) throws {
    let app = try App()
    let sub = args[1]

    switch sub {
    case nil, "show":
        guard let status = try app.budget.status() else {
            print(Term.dim("Kein Budget gesetzt."))
            print(Term.dim("connlimit budget set 5GB --until 2026-09-06"))
            return
        }
        print(Term.bold(status.budget.label))
        print("  Volumen      \(ByteFormat.short(status.budget.totalBytes))")
        print("  Verbraucht   \(ByteFormat.short(status.usedBytes))")
        print("  Übrig        " + Term.bold(ByteFormat.short(status.remainingBytes))
            + Term.dim("  (\(Int(status.remainingFraction * 100)) %)"))
        print("  Restlaufzeit \(String(format: "%.1f", status.remainingDays)) Tage")
        print("  Tagesbudget  \(ByteFormat.short(status.dailyAllowance))")
        print("  Heute        \(ByteFormat.short(status.usedTodayBytes))"
            + Term.dim("  Hochrechnung \(ByteFormat.short(status.projectedToday))"))
        let lightText: String
        switch status.light {
        case .green:  lightText = Term.green("● im Rahmen")
        case .yellow: lightText = Term.yellow("● leicht drüber")
        case .red:    lightText = Term.red("● zu schnell")
        }
        print("  Status       \(lightText)")
        print()
        print(Term.dim("Nur Traffic in teuren oder begrenzten Netzen zählt."))

    case "set":
        guard let volumeText = args[2], let bytes = ByteFormat.parse(volumeText) else {
            throw CLIError.usage("connlimit budget set <5GB> --until <2026-09-06> [--label \"Italien\"]")
        }
        guard let untilText = args.value("until"), let until = Parse.date(untilText) else {
            throw CLIError.usage("--until <YYYY-MM-DD> fehlt oder ist unlesbar")
        }
        let from = args.value("from").flatMap(Parse.date) ?? Date()
        let budget = Budget(totalBytes: bytes, startsAt: from, endsAt: until,
                            label: args.value("label") ?? "Reise")
        try app.store.saveBudget(budget)
        print(Term.green("✓ ") + "Budget: \(ByteFormat.short(bytes)) bis \(untilText)")
        if let status = try app.budget.status() {
            print(Term.dim("   Tagesbudget: \(ByteFormat.short(status.dailyAllowance))"))
        }

    case "clear":
        try app.store.saveBudget(nil)
        print(Term.green("✓ ") + "Budget gelöscht")

    default:
        throw CLIError.usage("connlimit budget [show|set|clear]")
    }
}

// MARK: - except

func cmdExcept(_ args: Args) throws {
    let app = try App()
    guard let sub = args[1] else {
        let state = app.store.policyState
        print(Term.bold("Ausnahmen"))
        print("  Immer erlaubt:  " + (state.alwaysAllow.isEmpty
            ? Term.dim("—") : state.alwaysAllow.sorted().joined(separator: ", ")))
        print("  Immer gesperrt: " + (state.alwaysBlock.isEmpty
            ? Term.dim("—") : state.alwaysBlock.sorted().joined(separator: ", ")))
        print()
        print(Term.dim("connlimit except allow <dienst>   — auch im Urlaubsmodus erlauben"))
        print(Term.dim("connlimit except block <dienst>   — immer sperren"))
        print(Term.dim("connlimit except clear <dienst>   — Ausnahme entfernen"))
        return
    }
    guard let query = args[2] else {
        throw CLIError.usage("connlimit except <allow|block|clear> <dienst>")
    }
    let service = try app.service(matching: query)
    var state = app.store.policyState

    switch sub {
    case "allow":
        state.alwaysAllow.insert(service.id)
        state.alwaysBlock.remove(service.id)
        print(Term.green("✓ ") + "\(service.name) bleibt immer erlaubt")
    case "block":
        guard service.isBlockable else {
            throw CLIError.usage("\(service.name) ist systemkritisch und kann nicht gesperrt werden.")
        }
        state.alwaysBlock.insert(service.id)
        state.alwaysAllow.remove(service.id)
        print(Term.green("✓ ") + "\(service.name) ist immer gesperrt")
    case "clear":
        state.alwaysAllow.remove(service.id)
        state.alwaysBlock.remove(service.id)
        print(Term.green("✓ ") + "Ausnahme für \(service.name) entfernt")
    default:
        throw CLIError.usage("connlimit except <allow|block|clear> <dienst>")
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
    print(Term.bold("connlimit läuft")
        + Term.dim(config.readOnly ? "  (nur messen, keine Sperren)" : "")
        + Term.dim("  ·  Strg-C zum Beenden"))

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
    print(Term.bold("Systemprüfung"))
    print()

    func check(_ label: String, _ ok: Bool, _ detail: String) {
        let mark = ok ? Term.green("✓") : Term.yellow("○")
        print("  \(mark) " + Term.pad(label, 26) + Term.dim(detail))
    }

    let nettopOK = FileManager.default.isExecutableFile(atPath: "/usr/bin/nettop")
    check("nettop", nettopOK, nettopOK ? "Messung verfügbar" : "fehlt — ohne geht nichts")

    let app = try App()
    let (identity, cls) = try app.refreshNetwork()
    check("Netzerkennung", !identity.isOffline,
          identity.isOffline ? "offline" : "\(identity.label) [\(cls.displayName)]")
    check("Gateway-MAC", identity.gatewayMAC != nil,
          identity.gatewayMAC ?? "nicht ermittelbar — Netz-ID weniger stabil")

    check("Datenbank", true, Store.defaultPath)

    check("root", Shell.isRoot,
          Shell.isRoot ? "launchd- und PF-Hebel verfügbar"
                       : "ohne sudo nur der Hebel 'App einfrieren'")

    check("PF-Anchor", PFAnchor.isInstalled,
          PFAnchor.isInstalled ? "installiert"
                               : "nicht installiert — 'sudo connlimit install-pf' für Domain-Sperren")

    let running = ProcessLookup.running().count
    check("Prozessliste", running > 0, "\(running) Prozesse sichtbar")

    let receipts = try app.store.openReceipts()
    check("Offene Sperren", receipts.isEmpty,
          receipts.isEmpty ? "keine" : "\(receipts.count) — 'connlimit status' zeigt sie")

    print()
    print(Term.dim("Was welcher Hebel wirklich tut, steht in der README."))
}

// MARK: - PF-Installation

func cmdInstallPF(_ args: Args) throws {
    guard Shell.isRoot else {
        throw CLIError.usage("Braucht root: sudo connlimit install-pf")
    }
    guard !PFAnchor.isInstalled else {
        print(Term.dim("PF-Anchor ist bereits installiert."))
        return
    }
    print("Fügt \(PFAnchor.anchorLine) zu /etc/pf.conf hinzu.")
    print(Term.dim("Eine Sicherung wird unter /etc/pf.conf.connlimit-backup abgelegt."))
    try PFAnchor.install()
    print(Term.green("✓ ") + "PF-Anchor installiert und Regelsatz neu geladen")
}

func cmdUninstallPF(_ args: Args) throws {
    guard Shell.isRoot else {
        throw CLIError.usage("Braucht root: sudo connlimit uninstall-pf")
    }
    try PFAnchor.uninstall()
    print(Term.green("✓ ") + "PF-Anchor entfernt, alle Regeln geleert")
}
