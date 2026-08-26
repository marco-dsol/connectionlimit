import Foundation
import ConnLimitCore

// MARK: - tracked

/// Die Dauerliste: alle Dienste, die je Daten gebraucht haben — auch die, die
/// gerade still sind. Aus dieser Liste heraus sperrt man.
func cmdTracked(_ args: Args) throws {
    let app = try App()
    let limit = args.value("limit").flatMap(Int.init) ?? 30
    let activeOnly = args.flag("active")
    let (identity, cls) = try app.refreshNetwork()
    let now = Date()

    let rows = try app.store.trackedUsage(catalog: app.catalog, now: now)
        .filter { !activeOnly || $0.isActive(now: now) }
    let since = try app.store.trackingSince()

    print(Term.bold("Getrackte Dienste")
        + Term.dim("  ·  seit \(since.map(stamp) ?? "—")")
        + Term.dim("  ·  Netz: \(identity.label) [\(cls.displayName)]"))
    print()

    guard !rows.isEmpty else {
        print(Term.dim("  Noch nichts gesehen. 'connlimit run' im Hintergrund starten "
                     + "oder die App öffnen — die Liste füllt sich beim Messen."))
        return
    }

    // Verlauf für alle Zeilen in einer Abfrage, nicht einer je Zeile.
    let window = now.addingTimeInterval(-24 * 3600)
    let history = try app.store.history(serviceIds: rows.map(\.id), since: window,
                                        until: now, bucket: 3600)

    print(Term.dim("  " + Term.pad("DIENST", 27) + Term.pad("KLASSE", 14)
                 + Term.padLeft("GESAMT", 11) + Term.padLeft("HEUTE", 11)
                 + "  " + Term.pad("ZULETZT", 11) + "VERLAUF 24 h"))

    for row in rows.prefix(limit) {
        let active = row.isActive(now: now)
        let marker: String
        if row.isLeaking(now: now) { marker = Term.yellow("⚠") }
        else if row.isBlocked      { marker = Term.red("🔒") }
        else if active             { marker = Term.green("●") }
        else                       { marker = " " }

        let shortName = Term.fit(row.service.name, 26)
        let name = active ? Term.green(shortName) : shortName
        let last = active ? Term.green("gerade")
                          : Term.dim(row.lastSeen.map(ago) ?? "—")

        print(Term.pad(marker, 2) + Term.pad(name, 27)
            + Term.pad(Term.dim(row.service.serviceClass.displayName), 14)
            + Term.padLeft(Term.bold(ByteFormat.short(row.total)), 11)
            + Term.padLeft(row.todayBytes > 0 ? ByteFormat.short(row.todayBytes) : Term.dim("—"), 11)
            + "  " + Term.pad(last, 11)
            + sparkline(history[row.id] ?? []))

        if row.attemptCount > 0 {
            print("  " + Term.yellow("↳ ") + Term.dim(
                "\(row.attemptCount)× trotz Sperre aktiv · \(ByteFormat.short(row.attemptBytes))"
                + (row.lastAttempt.map { " · zuletzt \(stamp($0))" } ?? "")))
        }
    }

    if rows.count > limit {
        print(Term.dim("  … und \(rows.count - limit) weitere"))
    }
    print()
    let total = rows.reduce(Int64(0)) { $0 + $1.total }
    let activeCount = rows.filter { $0.isActive(now: now) }.count
    print(Term.dim("Gesamt: ") + Term.bold(ByteFormat.short(total))
        + Term.dim("  ·  \(rows.count) Dienste  ·  ") + Term.green("\(activeCount) gerade aktiv"))
    print(Term.dim("Zurücksetzen: connlimit reset --all  ·  einzeln: connlimit reset <dienst>"))
}

// MARK: - history

func cmdHistory(_ args: Args) throws {
    guard let query = args[1] else {
        throw CLIError.usage("connlimit history <dienst> [--since 24h] [--bucket 1h]")
    }
    let app = try App()
    let service = try app.serviceOrTracked(matching: query)
    let since = args.value("since").flatMap(Parse.since) ?? Date().addingTimeInterval(-24 * 3600)
    let bucket = args.value("bucket").flatMap(Parse.duration) ?? 3600

    let buckets = try app.store.history(serviceId: service.id, since: since, bucket: bucket)
    print(Term.bold("Verlauf: \(service.name)")
        + Term.dim("  ·  Fenster \(durationText(bucket))"))
    print()

    guard !buckets.isEmpty, buckets.contains(where: { $0.total > 0 }) else {
        print(Term.dim("  Keine Messdaten in diesem Zeitraum."))
        if bucket < 3600 {
            print(Term.dim("  Unter einer Stunde reichen nur die Rohdaten der letzten 48 h."))
        }
        return
    }

    let peak = buckets.map(\.total).max() ?? 1
    let f = DateFormatter()
    f.dateFormat = bucket >= 86400 ? "dd.MM." : "dd.MM. HH:mm"
    for b in buckets {
        let bar = barGraph(Double(b.total) / Double(max(1, peak)), width: 32)
        print("  " + Term.dim(f.string(from: b.start)) + "  "
            + Term.padLeft(b.total > 0 ? ByteFormat.short(b.total) : Term.dim("—"), 10)
            + "  " + bar)
    }
    print()
    let total = buckets.reduce(Int64(0)) { $0 + $1.total }
    print(Term.dim("Summe: ") + Term.bold(ByteFormat.short(total))
        + Term.dim("  ·  Spitze \(ByteFormat.short(peak)) je Fenster"))
}

// MARK: - events

func cmdEvents(_ args: Args) throws {
    let app = try App()
    let since = args.value("since").flatMap(Parse.since) ?? Date().addingTimeInterval(-7 * 86400)
    let limit = args.value("limit").flatMap(Int.init) ?? 40
    let attemptsOnly = args.flag("attempts")

    var serviceId: String?
    var title = "Protokoll"
    if let query = args[1] {
        let service = try app.serviceOrTracked(matching: query)
        serviceId = service.id
        title = "Protokoll: \(service.name)"
    }

    let events = try app.store.events(serviceId: serviceId, since: since,
                                      kinds: attemptsOnly ? [.attempt] : nil, limit: limit)
    print(Term.bold(title) + Term.dim("  ·  seit \(stamp(since))"))
    print()

    guard !events.isEmpty else {
        print(Term.dim("  Keine Einträge. Protokolliert werden Sperren, Freigaben und "
                     + "Verkehr trotz Sperre."))
        return
    }

    for event in events {
        let name = app.catalog.serviceOrUnknown(id: event.serviceId).name
        let when = event.isEpisode
            ? "\(stamp(event.at))–\(clock(event.until))"
            : stamp(event.at)

        let label: String
        switch event.kind {
        case .blocked:  label = Term.red("gesperrt          ")
        case .released: label = Term.green("freigegeben       ")
        case .attempt:  label = Term.yellow("trotz Sperre aktiv")
        case .reset:    label = Term.dim("zurückgesetzt     ")
        }

        var line = "  " + Term.dim(Term.pad(when, 18)) + label + "  " + Term.fit(name, 24)
        if event.bytes > 0 { line += Term.bold(ByteFormat.short(event.bytes)) }
        if let detail = event.detail { line += Term.dim("  " + detail) }
        print(line)
    }
    print()
    print(Term.dim("Nur Durchbrüche: connlimit events --attempts"))
}

// MARK: - reset

func cmdReset(_ args: Args) throws {
    let app = try App()

    if args.flag("all") || args.value("all") != nil {
        let count = try app.store.trackedServices().count
        try app.store.resetTracking()
        print(Term.green("✓ ") + "Zählung zurückgesetzt — \(count) Dienste aus der Liste entfernt")
        print(Term.dim("  Messdaten und Budget bleiben unberührt; die Liste füllt sich neu."))
        return
    }

    guard let query = args[1] else {
        throw CLIError.usage("connlimit reset <dienst>   oder   connlimit reset --all")
    }
    let service = try app.serviceOrTracked(matching: query)
    guard try app.store.trackedService(id: service.id) != nil else {
        throw CLIError.notFound("\(service.name) steht nicht in der Liste.")
    }
    try app.store.resetTracking(serviceId: service.id)
    print(Term.green("✓ ") + Term.bold(service.name) + " aus der Liste entfernt")
    print(Term.dim("  Erscheint wieder, sobald der Dienst das nächste Mal Daten braucht."))
}

// MARK: - Hilfen

private let sparkLevels = Array("▁▂▃▄▅▆▇█")

/// Verlauf als eine Zeile. Leere Fenster bleiben leer statt auf der untersten
/// Stufe zu stehen — sonst sähe Stille wie schwacher Verkehr aus.
func sparkline(_ buckets: [HistoryBucket]) -> String {
    guard let peak = buckets.map(\.total).max(), peak > 0 else {
        return Term.dim(String(repeating: "·", count: min(24, max(1, buckets.count))))
    }
    let tail = buckets.suffix(24)
    return tail.map { bucket -> String in
        guard bucket.total > 0 else { return Term.dim("·") }
        let level = Int((Double(bucket.total) / Double(peak) * Double(sparkLevels.count - 1)).rounded())
        return String(sparkLevels[max(0, min(sparkLevels.count - 1, level))])
    }.joined()
}

private func barGraph(_ fraction: Double, width: Int) -> String {
    let filled = max(0, min(width, Int((fraction * Double(width)).rounded())))
    let color = fraction > 0.5 ? Term.red : (fraction > 0.2 ? Term.yellow : Term.green)
    return color(String(repeating: "█", count: filled))
         + Term.dim(String(repeating: "·", count: width - filled))
}

func stamp(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "dd.MM. HH:mm"
    return f.string(from: date)
}

private func clock(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

func ago(_ date: Date) -> String {
    let s = max(0, Date().timeIntervalSince(date))
    if s < 60 { return "vor \(Int(s)) s" }
    if s < 3600 { return "vor \(Int(s / 60)) min" }
    if s < 86400 { return "vor \(Int(s / 3600)) h" }
    return "vor \(Int(s / 86400)) T"
}

private func durationText(_ seconds: TimeInterval) -> String {
    if seconds >= 86400 { return "\(Int(seconds / 86400)) Tage" }
    if seconds >= 3600 { return "\(Int(seconds / 3600)) h" }
    return "\(Int(seconds / 60)) min"
}
