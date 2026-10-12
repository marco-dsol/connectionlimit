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

    print(Term.bold(L("Getrackte Dienste"))
        + Term.dim("  ·  " + L("seit %@", since.map(stamp) ?? "—"))
        + Term.dim("  ·  " + L("Netz: %@ [%@]", identity.displayLabel, cls.displayName)))
    print()

    guard !rows.isEmpty else {
        print(Term.dim("  " + L("Noch nichts gesehen. 'connlimit run' im Hintergrund starten oder die App öffnen — die Liste füllt sich beim Messen.")))
        return
    }

    // Verlauf für alle Zeilen in einer Abfrage, nicht einer je Zeile.
    let window = now.addingTimeInterval(-24 * 3600)
    let history = try app.store.history(serviceIds: rows.map(\.id), since: window,
                                        until: now, bucket: 3600)

    print(Term.dim("  " + Term.pad(L("DIENST"), 27) + Term.pad(L("KLASSE"), 14)
                 + Term.padLeft(L("GESAMT"), 11) + Term.padLeft(L("HEUTE"), 11)
                 + "  " + Term.pad(L("ZULETZT"), 11) + L("VERLAUF 24 h")))

    for row in rows.prefix(limit) {
        let active = row.isActive(now: now)
        let marker: String
        if row.isLeaking(now: now) { marker = Term.yellow("⚠") }
        else if row.isBlocked      { marker = Term.red("🔒") }
        else if active             { marker = Term.green("●") }
        else                       { marker = " " }

        let shortName = Term.fit(row.service.displayName, 26)
        let name = active ? Term.green(shortName) : shortName
        let last = active ? Term.green(L("gerade"))
                          : Term.dim(row.lastSeen.map(ago) ?? "—")

        print(Term.pad(marker, 2) + Term.pad(name, 27)
            + Term.pad(Term.dim(row.service.serviceClass.displayName), 14)
            + Term.padLeft(Term.bold(ByteFormat.short(row.total)), 11)
            + Term.padLeft(row.todayBytes > 0 ? ByteFormat.short(row.todayBytes) : Term.dim("—"), 11)
            + "  " + Term.pad(last, 11)
            + sparkline(history[row.id] ?? []))

        if row.attemptCount > 0 {
            print("  " + Term.yellow("↳ ") + Term.dim(
                L("%@× trotz Sperre aktiv · %@", row.attemptCount, ByteFormat.short(row.attemptBytes))
                + (row.lastAttempt.map { " · " + L("zuletzt %@", stamp($0)) } ?? "")))
        }
    }

    if rows.count > limit {
        print(Term.dim("  " + L("… und %@ weitere", rows.count - limit)))
    }
    print()
    let total = rows.reduce(Int64(0)) { $0 + $1.total }
    let activeCount = rows.filter { $0.isActive(now: now) }.count
    print(Term.dim(L("Gesamt: ")) + Term.bold(ByteFormat.short(total))
        + Term.dim("  ·  " + L("%@ Dienste", rows.count) + "  ·  ")
        + Term.green(L("%@ gerade aktiv", activeCount)))
    print(Term.dim(L("Zurücksetzen: connlimit reset --all  ·  einzeln: connlimit reset <dienst>")))
}

// MARK: - history

func cmdHistory(_ args: Args) throws {
    guard let query = args[1] else {
        throw CLIError.usage(L("connlimit history <dienst> [--since 24h] [--bucket 1h]"))
    }
    let app = try App()
    let service = try app.serviceOrTracked(matching: query)
    let since = args.value("since").flatMap(Parse.since) ?? Date().addingTimeInterval(-24 * 3600)
    let bucket = args.value("bucket").flatMap(Parse.duration) ?? 3600

    let buckets = try app.store.history(serviceId: service.id, since: since, bucket: bucket)
    print(Term.bold(L("Verlauf: %@", service.displayName))
        + Term.dim("  ·  " + L("Fenster %@", durationText(bucket))))
    print()

    guard !buckets.isEmpty, buckets.contains(where: { $0.total > 0 }) else {
        print(Term.dim("  " + L("Keine Messdaten in diesem Zeitraum.")))
        if bucket < 3600 {
            print(Term.dim("  " + L("Unter einer Stunde reichen nur die Rohdaten der letzten 48 h.")))
        }
        return
    }

    let peak = buckets.map(\.total).max() ?? 1
    let dayOnly = bucket >= 86400
    for b in buckets {
        let bar = barGraph(Double(b.total) / Double(max(1, peak)), width: 32)
        let when = DisplayTime.dayAndTime(b.start)
        let label = dayOnly ? String(when.dropLast(6)) : when
        print("  " + Term.dim(Term.pad(label, 13)) + " "
            + Term.padLeft(b.total > 0 ? ByteFormat.short(b.total) : Term.dim("—"), 10)
            + "  " + bar)
    }
    print()
    let total = buckets.reduce(Int64(0)) { $0 + $1.total }
    print(Term.dim(L("Summe: ")) + Term.bold(ByteFormat.short(total))
        + Term.dim("  ·  " + L("Spitze %@ je Fenster", ByteFormat.short(peak))))
}

// MARK: - events

func cmdEvents(_ args: Args) throws {
    let app = try App()
    let since = args.value("since").flatMap(Parse.since) ?? Date().addingTimeInterval(-7 * 86400)
    let limit = args.value("limit").flatMap(Int.init) ?? 40
    let attemptsOnly = args.flag("attempts")

    var serviceId: String?
    var title = L("Protokoll")
    if let query = args[1] {
        let service = try app.serviceOrTracked(matching: query)
        serviceId = service.id
        title = L("Protokoll: %@", service.displayName)
    }

    let events = try app.store.events(serviceId: serviceId, since: since,
                                      kinds: attemptsOnly ? [.attempt] : nil, limit: limit)
    print(Term.bold(title) + Term.dim("  ·  " + L("seit %@", stamp(since))))
    print()

    guard !events.isEmpty else {
        print(Term.dim("  " + L("Keine Einträge. Protokolliert werden Sperren, Freigaben und Verkehr trotz Sperre.")))
        return
    }

    // Alle Bezeichnungen gleich breit, in jeder Sprache: sonst springt die
    // Namensspalte je nach Ereignis hin und her.
    let kindWidth = ServiceEvent.Kind.allCases.map(\.displayName.count).max() ?? 18
    for event in events {
        let name = app.catalog.serviceOrUnknown(id: event.serviceId).displayName
        let when = event.isEpisode
            ? "\(stamp(event.at))–\(DisplayTime.clock(event.until))"
            : stamp(event.at)

        let text = Term.pad(event.kind.displayName, kindWidth)
        let label: String
        switch event.kind {
        case .blocked:  label = Term.red(text)
        case .released: label = Term.green(text)
        case .attempt:  label = Term.yellow(text)
        case .reset:    label = Term.dim(text)
        }

        var line = "  " + Term.dim(Term.pad(when, 18)) + label + "  " + Term.fit(name, 24)
        if event.bytes > 0 { line += Term.bold(ByteFormat.short(event.bytes)) }
        if let detail = event.displayDetail { line += Term.dim("  " + detail) }
        print(line)
    }
    print()
    print(Term.dim(L("Nur Durchbrüche: connlimit events --attempts")))
}

// MARK: - reset

func cmdReset(_ args: Args) throws {
    let app = try App()

    if args.flag("all") || args.value("all") != nil {
        let count = try app.store.trackedServices().count
        try app.store.resetTracking()
        print(Term.green("✓ ") + L("Zählung zurückgesetzt — %@ Dienste aus der Liste entfernt", count))
        print(Term.dim("  " + L("Messdaten und Budget bleiben unberührt; die Liste füllt sich neu.")))
        return
    }

    guard let query = args[1] else {
        throw CLIError.usage(L("connlimit reset <dienst>   oder   connlimit reset --all"))
    }
    let service = try app.serviceOrTracked(matching: query)
    guard try app.store.trackedService(id: service.id) != nil else {
        throw CLIError.notFound(L("%@ steht nicht in der Liste.", service.displayName))
    }
    try app.store.resetTracking(serviceId: service.id)
    print(Term.green("✓ ") + L("%@ aus der Liste entfernt", Term.bold(service.displayName)))
    print(Term.dim("  " + L("Erscheint wieder, sobald der Dienst das nächste Mal Daten braucht.")))
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

func stamp(_ date: Date) -> String { DisplayTime.stamp(date) }

/// Wie `DisplayTime.ago`, aber mit Tagen als „T" — die Spalte im Terminal ist
/// schmal, und „vor 12 Tagen" schöbe die Tabelle auseinander.
func ago(_ date: Date) -> String {
    let s = max(0, Date().timeIntervalSince(date))
    guard s >= 86400 else { return DisplayTime.ago(date) }
    return L("vor %@ T", Int(s / 86400))
}

private func durationText(_ seconds: TimeInterval) -> String {
    if seconds >= 86400 { return L("%@ Tage", Int(seconds / 86400)) }
    if seconds >= 3600 { return "\(Int(seconds / 3600)) h" }
    return "\(Int(seconds / 60)) min"
}
