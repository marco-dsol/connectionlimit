import Foundation
import ConnLimitCore

// MARK: - status

func cmdStatus(_ args: Args) throws {
    let app = try App()
    let (identity, cls) = try app.refreshNetwork()
    let tier = app.policy.effectiveTier(networkClass: cls)
    let state = app.store.policyState

    print(Term.bold("ConnectionLimit"))
    print()

    let classColor: (String) -> String = {
        switch cls {
        case .free:    return Term.green
        case .metered: return Term.red
        case .limited: return Term.yellow
        case .unknown: return Term.dim
        }
    }()
    print(Term.pad(L("Netz"), 14) + identity.displayLabel
        + "  " + classColor("[\(cls.displayName)]")
        + Term.dim("  \(identity.interface) · \(identity.gatewayMAC ?? identity.gatewayIP)"))

    let tierNote = state.manualTier != nil ? L("manuell gesetzt")
                 : (state.followNetwork ? L("folgt dem Netz") : L("Automatik aus"))
    print(Term.pad(L("Profil"), 14) + Term.bold(tier.displayName)
        + Term.dim("  (\(tierNote)) — \(state.summary(for: tier))")
        + (state.isCustomized(tier) ? Term.dim("  [" + L("angepasst") + "]") : ""))

    if let status = try app.budget.status() {
        let light: String
        switch status.light {
        case .green:  light = Term.green("●")
        case .yellow: light = Term.yellow("●")
        case .red:    light = Term.red("●")
        }
        print(Term.pad(L("Budget"), 14) + light + " "
            + L("%@ von %@ übrig", ByteFormat.short(status.remainingBytes),
                ByteFormat.short(status.budget.totalBytes))
            + Term.dim("  ·  " + L("%@ Tage", String(format: "%.1f", status.remainingDays))))
        print(Term.pad("", 14) + Term.dim(L("heute %@ · Tagesbudget %@ · Hochrechnung %@",
            ByteFormat.short(status.usedTodayBytes), ByteFormat.short(status.dailyAllowance),
            ByteFormat.short(status.projectedToday))))
    } else {
        print(Term.pad(L("Budget"), 14) + Term.dim(L("nicht gesetzt — 'connlimit budget set 5GB --until 2026-09-06'")))
    }

    let receipts = try app.store.openReceipts()
    let grants = try app.store.grants().filter { !$0.isExpired }

    print()
    if receipts.isEmpty {
        print(Term.dim(L("Keine aktiven Sperren.")))
    } else {
        print(Term.bold(L("Aktive Sperren (%@)", receipts.count)))
        for r in receipts.sorted(by: { $0.serviceId < $1.serviceId }) {
            let name = app.catalog.serviceOrUnknown(id: r.serviceId).displayName
            var detail = "\(r.lever.displayName) · \(r.reason.displayName)"
            if let expires = r.expiresAt {
                detail += " · " + L("endet in %@", remaining(expires))
            }
            print("  🔒 " + Term.pad(name, 26) + Term.dim(detail))
        }
    }

    if !grants.isEmpty {
        print()
        print(Term.bold(L("Freigaben auf Zeit")))
        for g in grants {
            let name = app.catalog.serviceOrUnknown(id: g.serviceId).displayName
            let used = (try? app.store.serviceTotal(g.serviceId)) ?? 0
            let spent = max(0, used - g.bytesAtStart)
            print("  ⏱  " + Term.pad(name, 26)
                + Term.dim(L("noch %@ · bisher %@", remaining(g.until), ByteFormat.short(spent))))
        }
    }

    if !state.alwaysAllow.isEmpty || !state.alwaysBlock.isEmpty {
        print()
        if !state.alwaysAllow.isEmpty {
            print(Term.dim(L("Immer erlaubt: ")) + state.alwaysAllow.sorted().joined(separator: ", "))
        }
        if !state.alwaysBlock.isEmpty {
            print(Term.dim(L("Immer gesperrt: ")) + state.alwaysBlock.sorted().joined(separator: ", "))
        }
    }
}

func remaining(_ date: Date) -> String { DisplayTime.remaining(until: date) }

// MARK: - block / allow

func cmdBlock(_ args: Args) throws {
    guard let query = args[1] else {
        throw CLIError.usage(L("connlimit block <dienst> [--for 30m]"))
    }
    let app = try App()
    let service = try app.service(matching: query)
    let (identity, _) = try app.refreshNetwork()

    var until: Date?
    if let forValue = args.value("for") {
        guard let duration = Parse.duration(forValue) else {
            throw CLIError.usage(L("Dauer nicht verstanden: '%@' (z. B. 30m, 2h)", forValue))
        }
        until = Date().addingTimeInterval(duration)
    }

    try app.agent.tickSampling()   // frische PID-Zuordnung
    let receipt = try app.coordinator.block(
        service,
        context: EnforcementContext(network: identity, livePIDs: [:]),
        reason: until == nil ? .manual : .timer,
        until: until)

    var line = Term.red("🔒 ") + L("%@ gesperrt", Term.bold(service.displayName))
    line += Term.dim(" (" + L("Hebel: %@", receipt.lever.displayName) + ")")
    if let until { line += Term.dim(" · " + L("frei in %@", remaining(until))) }
    print(line)
    if let note = receipt.lever.bluntnessNote {
        print(Term.dim("   ↳ \(note)"))
    }
}

func cmdAllow(_ args: Args) throws {
    guard let query = args[1] else {
        throw CLIError.usage(L("connlimit allow <dienst> [--for 30m]"))
    }
    let app = try App()
    let service = try app.service(matching: query)

    if let forValue = args.value("for") {
        guard let duration = Parse.duration(forValue) else {
            throw CLIError.usage(L("Dauer nicht verstanden: '%@' (z. B. 30m, 2h)", forValue))
        }
        let grant = try app.policy.grant(service, duration: duration)
        print(Term.green("⏱  ") + L("%@ für %@ freigegeben", Term.bold(service.displayName),
                                     remaining(grant.until)))
        print(Term.dim("   " + L("Danach greift das Profil wieder. Der Verbrauch in diesem Fenster wird ausgewiesen.")))
    } else {
        try app.coordinator.unblock(serviceId: service.id)
        print(Term.green("✓ ") + L("%@ freigegeben", Term.bold(service.displayName)))
    }
}

func cmdUnblockAll(_ args: Args) throws {
    let app = try App()
    let count = try app.store.openReceipts().count
    try app.coordinator.emergencyRelease()
    print(Term.green("✓ ") + L("Alle Sperren aufgehoben (%@)", count))
    if !Shell.isRoot {
        print(Term.dim("   " + L("Hinweis: PF- und launchd-Sperren brauchen root — ggf. 'sudo connlimit unblock-all' nachziehen.")))
    }
}

// MARK: - profile

func cmdProfile(_ args: Args) throws {
    let app = try App()

    // Unterbefehle vor der Stufenwahl prüfen — 'edit' ist keine Stufe.
    if let sub = args[1]?.lowercased(), sub == "edit" {
        try profileEdit(app, args)
        return
    }

    guard let arg = args[1] else {
        let (_, cls) = try app.refreshNetwork()
        let state = app.store.policyState
        let tier = app.policy.effectiveTier(networkClass: cls)
        print(Term.bold(L("Profil: ") + tier.displayName) + Term.dim(" — \(state.summary(for: tier))"))
        print()
        for t in PolicyTier.allCases {
            let mark = t == tier ? Term.green("●") : Term.dim("○")
            let classes = state.blockedClasses(for: t)
            let text = classes.isEmpty ? "—"
                : ServiceClass.allCases.filter { classes.contains($0) }
                    .map(\.displayName).joined(separator: ", ")
            print("  \(mark) " + Term.pad(t.displayName, 16) + Term.dim(text)
                + (state.isCustomized(t) ? Term.yellow("  ✎") : ""))
        }
        if !state.inconsistentTiers.isEmpty {
            print()
            print(Term.yellow("  ⚠ ") + L("Diese Stufen sperren weniger als eine niedrigere: %@",
                state.inconsistentTiers.map(\.displayName).joined(separator: ", ")))
            print(Term.dim("    " + L("Die Budget-Automatik stuft nur hoch — sie würde dabei lockern.")))
        }
        print()
        print(Term.dim(L("connlimit profile <aus|sparsam|urlaub|notfall|auto>")))
        print(Term.dim(L("connlimit profile edit <stufe> <klassen…>   Belegung ändern")))
        return
    }

    var state = app.store.policyState
    if arg.lowercased() == "auto" {
        state.manualTier = nil
        state.followNetwork = true
        try app.store.savePolicyState(state)
        print(Term.green("✓ ") + L("Profil folgt wieder dem Netz"))
    } else {
        guard let tier = Parse.tier(arg) else {
            throw CLIError.usage(L("Unbekanntes Profil '%@'. Erlaubt: aus, sparsam, urlaub, notfall, auto", arg))
        }
        state.manualTier = tier
        try app.store.savePolicyState(state)
        print(Term.green("✓ ") + L("Profil: ") + Term.bold(tier.displayName)
            + Term.dim(" — \(state.summary(for: tier))"))
    }

    let (identity, cls) = try app.refreshNetwork()
    try app.agent.tickSampling()
    let report = try app.policy.apply(
        networkClass: cls, context: EnforcementContext(network: identity, livePIDs: [:]))
    printReport(report)
}

/// `connlimit profile edit <stufe> <klassen…>` — legt fest, was eine Stufe
/// sperrt. Ohne Klassenangabe wird die Belegung angezeigt, mit `--default`
/// auf die Voreinstellung zurückgesetzt.
private func profileEdit(_ app: App, _ args: Args) throws {
    guard let tierArg = args[2], let tier = Parse.tier(tierArg) else {
        throw CLIError.usage(L("connlimit profile edit <sparsam|urlaub|notfall> <klassen…>") + "\n"
                           + "  " + L("Klassen: ") + editableClassList())
    }
    guard tier.isEditable else {
        throw CLIError.usage(L("Die Stufe „Aus“ sperrt nichts — das ist nicht verhandelbar."))
    }

    var state = app.store.policyState

    if args.flag("default") || args.value("default") != nil {
        state.resetTier(tier)
        try app.store.savePolicyState(state)
        print(Term.green("✓ ") + L("%@ wieder auf Voreinstellung: ", tier.displayName)
            + Term.dim(state.summary(for: tier)))
        try reapply(app)
        return
    }

    let rest = args.positional.dropFirst(3).flatMap { $0.split(separator: ",") }.map(String.init)
    guard !rest.isEmpty else {
        let classes = state.blockedClasses(for: tier)
        print(Term.bold(tier.displayName)
            + Term.dim("  (" + (state.isCustomized(tier) ? L("angepasst") : L("Voreinstellung")) + ")"))
        for cls in ServiceClass.allCases where cls.isBlockable {
            let on = classes.contains(cls)
            print("  " + (on ? Term.red("■") : Term.dim("□")) + " "
                + Term.pad(cls.displayName, 16) + Term.dim(cls.rawValue))
        }
        print()
        print(Term.dim(L("Setzen (Komma oder Leerzeichen, ersetzt die ganze Belegung):")))
        print(Term.dim("  connlimit profile edit \(tierArg) update backup media"))
        print(Term.dim(L("Zurück auf Voreinstellung:")))
        print(Term.dim("  connlimit profile edit \(tierArg) --default"))
        print(Term.dim(L("Klassen: ") + editableClassList()))
        return
    }

    var selected: Set<ServiceClass> = []
    for token in rest {
        guard let cls = parseClass(token) else {
            throw CLIError.usage(L("Unbekannte Klasse '%@'. Erlaubt: ", token) + editableClassList())
        }
        guard cls.isBlockable else {
            throw CLIError.usage(L("„%@“ ist hart geschützt und lässt sich keiner Stufe zuordnen.",
                                   cls.displayName))
        }
        selected.insert(cls)
    }

    state.setBlockedClasses(selected, for: tier)
    try app.store.savePolicyState(state)
    print(Term.green("✓ ") + L("%@ sperrt jetzt: %@", Term.bold(tier.displayName),
                               state.summary(for: tier)))
    if state.inconsistentTiers.contains(tier) {
        print(Term.yellow("  ⚠ ") + L("Diese Stufe sperrt weniger als eine niedrigere — die Budget-Automatik würde beim Hochstufen lockern."))
    }
    try reapply(app)
}

private func reapply(_ app: App) throws {
    let (identity, cls) = try app.refreshNetwork()
    try app.agent.tickSampling()
    let report = try app.policy.apply(
        networkClass: cls, context: EnforcementContext(network: identity, livePIDs: [:]))
    printReport(report)
}

private func editableClassList() -> String {
    ServiceClass.allCases.filter(\.isBlockable).map(\.rawValue).joined(separator: ", ")
}

/// Klassen sind über die technische Kennung *und* den angezeigten Namen
/// erreichbar, deutsch wie englisch — beides steht in der Ausgabe, also muss
/// beides funktionieren.
private func parseClass(_ text: String) -> ServiceClass? {
    let t = text.trimmingCharacters(in: .whitespaces).lowercased()
    if let direct = ServiceClass(rawValue: t) { return direct }
    switch t {
    case "updates", "update":                 return .update
    case "backup", "backups", "sicherung":    return .backup
    case "telemetrie", "telemetry":           return .telemetry
    case "medien", "media":                   return .media
    case "cloud-sync", "cloud", "sync":       return .sync
    case "e-mail", "email", "mail":           return .mail
    case "browser":                           return .browser
    case "messenger", "messaging":            return .messaging
    case "sonstiges", "other":                return .other
    case "systemkritisch":                    return .essential
    default:                                  return nil
    }
}

func printReport(_ report: PolicyEngine.SyncReport) {
    if !report.blocked.isEmpty {
        print(Term.red("   " + L("gesperrt: ")) + report.blocked.joined(separator: ", "))
    }
    if !report.released.isEmpty {
        print(Term.green("   " + L("freigegeben: ")) + report.released.joined(separator: ", "))
    }
    for f in report.failed {
        print(Term.yellow("   ⚠ \(f.service): ") + Term.dim(f.reason))
    }
    if !report.needsRoot.isEmpty {
        print(Term.yellow("   ⚠ " + L("braucht sudo: ")) + report.needsRoot.joined(separator: ", "))
        print(Term.dim("     " + L("Diese Dienste laufen weiter. 'sudo connlimit profile …' sperrt sie wirklich.")))
    }
    if report.blocked.isEmpty && report.released.isEmpty
        && report.failed.isEmpty && report.needsRoot.isEmpty {
        print(Term.dim("   " + L("keine Änderung")))
    }
}
