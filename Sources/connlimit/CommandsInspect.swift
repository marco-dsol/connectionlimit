import Foundation
import ConnLimitCore

// MARK: - top

func cmdTop(_ args: Args) throws {
    let app = try App()
    let since = args.value("since").flatMap(Parse.since) ?? Date().addingTimeInterval(-3600)
    let limit = args.value("limit").flatMap(Int.init) ?? 20
    let meteredOnly = args.flag("metered")

    let (identity, cls) = try app.refreshNetwork()
    let rows = try app.store.usage(since: since,
                                   networkClasses: meteredOnly ? [.metered, .limited] : nil)
    let blocked = try app.coordinator.blockedServiceIds()

    print(Term.bold("Verbrauch seit \(relative(since))")
          + Term.dim("  ·  Netz: \(identity.label) [\(cls.displayName)]"))
    print()

    guard !rows.isEmpty else {
        print(Term.dim("  Noch keine Messdaten. 'connlimit run' im Hintergrund starten "
                     + "oder 'connlimit watch' für eine Live-Ansicht."))
        return
    }

    let total = rows.reduce(0) { $0 + $1.total }
    let maxTotal = rows.first?.total ?? 1

    print(Term.dim(Term.pad("DIENST", 28) + Term.pad("KLASSE", 14)
                 + Term.padLeft("GESAMT", 11) + "  " + Term.padLeft("↓", 10)
                 + Term.padLeft("↑", 10) + "  ANTEIL"))

    for row in rows.prefix(limit) {
        let service = app.catalog.service(id: row.serviceId)
            ?? Service.unknown(processName: row.serviceId
                .replacingOccurrences(of: "unknown:", with: ""))
        let isBlocked = blocked.contains(row.serviceId)
        let name = (isBlocked ? "🔒 " : "   ") + service.name
        let bar = sparkbar(Double(row.total) / Double(max(1, maxTotal)))

        print(Term.pad(name, 28)
            + Term.pad(Term.dim(service.serviceClass.displayName), 14)
            + Term.padLeft(Term.bold(ByteFormat.short(row.total)), 11) + "  "
            + Term.padLeft(Term.dim(ByteFormat.short(row.bytesIn)), 10)
            + Term.padLeft(Term.dim(ByteFormat.short(row.bytesOut)), 10) + "  "
            + bar)
    }

    if rows.count > limit {
        print(Term.dim("  … und \(rows.count - limit) weitere"))
    }
    print()
    print(Term.bold("Gesamt: \(ByteFormat.short(total))"))
}

private func sparkbar(_ fraction: Double, width: Int = 12) -> String {
    let filled = max(0, min(width, Int((fraction * Double(width)).rounded())))
    let color = fraction > 0.5 ? Term.red : (fraction > 0.2 ? Term.yellow : Term.green)
    return color(String(repeating: "█", count: filled))
         + Term.dim(String(repeating: "·", count: width - filled))
}

private func relative(_ date: Date) -> String {
    let seconds = Date().timeIntervalSince(date)
    if seconds > 86400 * 365 * 10 { return "Beginn der Aufzeichnung" }
    if seconds < 3600 { return "\(Int(seconds / 60)) min" }
    if seconds < 86400 { return "\(Int(seconds / 3600)) h" }
    return "\(Int(seconds / 86400)) Tagen"
}

// MARK: - watch

func cmdWatch(_ args: Args) throws {
    let app = try App()
    let interval = args.value("interval").flatMap(Double.init) ?? 2
    try app.refreshNetwork()

    signal(SIGINT) { _ in
        print("\u{1B}[?25h")   // Cursor wieder einblenden
        exit(0)
    }
    print("\u{1B}[?25l")       // Cursor aus
    defer { print("\u{1B}[?25h") }

    // Erster Takt setzt nur die Basislinie — Zuwächse gibt es erst ab dem zweiten.
    try app.agent.tickSampling()

    while true {
        Thread.sleep(forTimeInterval: interval)
        try app.agent.tickSampling()

        let rates = app.agent.rates.filter { $0.value > 128 }   // Rauschen ausblenden
            .sorted { $0.value > $1.value }
        let (identity, cls) = app.agent.network
        let blocked = (try? app.coordinator.blockedServiceIds()) ?? []
        let tier = app.policy.effectiveTier(networkClass: cls)

        print("\u{1B}[2J\u{1B}[H", terminator: "")
        print(Term.bold("connlimit watch") + Term.dim("  ·  Strg-C zum Beenden"))
        print(Term.dim("Netz: ") + identity.label
            + Term.dim(" [\(cls.displayName)]  ·  Profil: ") + tier.displayName
            + Term.dim("  ·  gesperrt: ") + "\(blocked.count)")
        print()

        if rates.isEmpty {
            print(Term.dim("  Gerade keine nennenswerte Aktivität."))
        } else {
            let peak = rates.first?.value ?? 1
            print(Term.dim(Term.pad("DIENST", 30) + Term.padLeft("RATE", 12) + "  AKTIVITÄT"))
            for (serviceId, rate) in rates.prefix(15) {
                let service = app.catalog.service(id: serviceId)
                let name = service?.name
                    ?? serviceId.replacingOccurrences(of: "unknown:", with: "")
                let marker = blocked.contains(serviceId) ? "🔒 " : "   "
                print(Term.pad(marker + name, 30)
                    + Term.padLeft(Term.bold(ByteFormat.rate(rate)), 12) + "  "
                    + sparkbar(rate / max(1, peak), width: 20))
            }
        }
        let total = rates.reduce(0.0) { $0 + $1.value }
        print()
        print(Term.dim("Summe: ") + Term.bold(ByteFormat.rate(total)))
    }
}

// MARK: - services

func cmdServices(_ args: Args) throws {
    let app = try App()
    let filter = args.value("class").flatMap { ServiceClass(rawValue: $0) }
    let blocked = try app.coordinator.blockedServiceIds()

    let grouped = Dictionary(grouping: app.catalog.services) { $0.serviceClass }
    for cls in ServiceClass.allCases {
        guard filter == nil || filter == cls else { continue }
        guard let list = grouped[cls], !list.isEmpty else { continue }

        let state = app.store.policyState
        let tiers = PolicyTier.allCases.filter { state.blockedClasses(for: $0).contains(cls) }
        let tierNote = tiers.isEmpty
            ? (cls.isBlockable ? "nur manuell" : "nie sperrbar")
            : "ab \(tiers.map(\.displayName).first ?? "")"

        print(Term.bold(cls.displayName) + Term.dim("  — \(tierNote)"))
        for service in list.sorted(by: { $0.name < $1.name }) {
            let mark = blocked.contains(service.id) ? Term.red("🔒") : "  "
            let lever = service.levers.first.map { $0.kind.rawValue } ?? "—"
            let warn = service.levers.first?.kind.bluntnessNote
            print("  \(mark) " + Term.pad(service.name, 28)
                + Term.pad(Term.dim(service.id), 22)
                + Term.dim(lever))
            if let warn, !service.levers.isEmpty {
                print("       " + Term.dim("↳ \(warn)"))
            }
            if let note = service.note {
                print("       " + Term.dim(note))
            }
        }
        print()
    }
}
