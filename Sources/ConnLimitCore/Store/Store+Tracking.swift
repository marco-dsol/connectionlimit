import Foundation

/// Dauerbeobachtung, Protokoll und Mengenverlauf.
///
/// Die drei hängen zusammen: `tracked_service` sagt **wer** je Daten gebraucht
/// hat, `service_event` **wann** etwas Bemerkenswertes passiert ist, und der
/// Verlauf **wie viel** über die Zeit. Erst zusammen ergeben sie eine Liste,
/// aus der heraus man sinnvoll sperren kann.
extension Store {

    // MARK: - Dauerbeobachtung

    /// Alle je gesehenen Dienste, der zuletzt aktive zuerst.
    public func trackedServices() throws -> [TrackedService] {
        try db.query("""
            SELECT service_id, first_seen, last_seen, bytes_in, bytes_out
            FROM tracked_service ORDER BY last_seen DESC
            """) { r in
            TrackedService(serviceId: r.text(0),
                           firstSeen: Date(timeIntervalSince1970: TimeInterval(r.int(1))),
                           lastSeen: Date(timeIntervalSince1970: TimeInterval(r.int(2))),
                           bytesIn: r.int(3), bytesOut: r.int(4))
        }
    }

    public func trackedService(id: String) throws -> TrackedService? {
        try db.query("""
            SELECT service_id, first_seen, last_seen, bytes_in, bytes_out
            FROM tracked_service WHERE service_id = ?
            """, [.text(id)]) { r in
            TrackedService(serviceId: r.text(0),
                           firstSeen: Date(timeIntervalSince1970: TimeInterval(r.int(1))),
                           lastSeen: Date(timeIntervalSince1970: TimeInterval(r.int(2))),
                           bytesIn: r.int(3), bytesOut: r.int(4))
        }.first
    }

    /// Beginn der Zählung insgesamt — für die Zeile „seit …" über der Liste.
    public func trackingSince() throws -> Date? {
        guard let raw = try kv("tracking_since"), let value = Int64(raw) else {
            // Kein Reset bisher: der älteste Eintrag ist der Beginn.
            return try db.query("SELECT MIN(first_seen) FROM tracked_service") { $0.intOrNil(0) }
                .compactMap { $0 }.first.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        }
        return Date(timeIntervalSince1970: TimeInterval(value))
    }

    /// Zählung zurücksetzen — für einen Dienst oder für alle.
    ///
    /// Gelöscht werden Merkposten und Protokoll, **nicht** die Messdaten:
    /// an denen hängt das Budget, und ein Reset der Liste soll nicht die
    /// Abrechnung der laufenden Reise verändern. Damit die Liste trotzdem
    /// wieder bei null anfängt, begrenzen die Verlaufsabfragen sich auf den
    /// Zeitraum ab `first_seen` des jeweiligen Eintrags.
    public func resetTracking(serviceId: String? = nil, now: Date = Date()) throws {
        let ts = Int64(now.timeIntervalSince1970)
        try db.transaction {
            if let serviceId {
                try db.run("DELETE FROM tracked_service WHERE service_id = ?", [.text(serviceId)])
                try db.run("DELETE FROM service_event WHERE service_id = ?", [.text(serviceId)])
            } else {
                try db.run("DELETE FROM tracked_service")
                try db.run("DELETE FROM service_event")
                try db.run("""
                    INSERT INTO kv (key, value) VALUES ('tracking_since', ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """, [.text(String(ts))])
            }
        }
    }

    /// Einmalige Übernahme vorhandener Messdaten beim ersten Start nach dem
    /// Update. Ohne das stünde die Liste nach dem Umstieg leer da, obwohl die
    /// Datenbank längst weiß, wer Daten gebraucht hat.
    func backfillTracking() throws {
        guard try kv("tracked_backfilled") == nil else { return }

        // Zeitgrenzen aus beiden Quellen: die Stundentabelle reicht weiter
        // zurück, die Rohdaten sind aktueller.
        var span: [String: (first: Int64, last: Int64)] = [:]
        func note(_ id: String, _ first: Int64, _ last: Int64) {
            if let existing = span[id] {
                span[id] = (min(existing.first, first), max(existing.last, last))
            } else {
                span[id] = (first, last)
            }
        }
        let hourlySpan = try db.query(
            "SELECT service_id, MIN(hour), MAX(hour) FROM usage_hourly GROUP BY service_id",
            [], { ($0.text(0), $0.int(1), $0.int(2)) })
        let rawSpan = try db.query(
            "SELECT service_id, MIN(ts), MAX(ts) FROM sample GROUP BY service_id",
            [], { ($0.text(0), $0.int(1), $0.int(2)) })
        for (id, mn, mx) in hourlySpan + rawSpan { note(id, mn, mx) }

        // Summen über `usage`, damit der Überlappungsbereich zwischen Rohdaten
        // und Stundentabelle nicht doppelt zählt.
        let totals = try usage(since: Date(timeIntervalSince1970: 0))
        try db.transaction {
            for row in totals {
                guard let s = span[row.serviceId] else { continue }
                try db.run("""
                    INSERT INTO tracked_service (service_id, first_seen, last_seen, bytes_in, bytes_out)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(service_id) DO NOTHING
                    """,
                    [.text(row.serviceId), .int(s.first), .int(s.last),
                     .int(row.bytesIn), .int(row.bytesOut)])
            }
            try db.run("""
                INSERT INTO kv (key, value) VALUES ('tracked_backfilled', '1')
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """)
        }
    }

    // MARK: - Sperrzustand

    /// Gesperrte Dienste, ohne die Quittungen zu entschlüsseln.
    ///
    /// Läuft im 2-s-Takt des Samplings mit; `openReceipts()` würde dabei jedes
    /// Mal jede Payload durch den JSON-Decoder schicken.
    public func blockedServiceIds() throws -> Set<String> {
        Set(try db.query("SELECT DISTINCT service_id FROM receipt") { $0.text(0) })
    }

    // MARK: - Protokoll

    @discardableResult
    public func logEvent(_ kind: ServiceEvent.Kind, serviceId: String,
                         bytes: Int64 = 0, detail: String? = nil,
                         at now: Date = Date()) throws -> ServiceEvent {
        let ts = Int64(now.timeIntervalSince1970)
        try db.run("""
            INSERT INTO service_event (service_id, kind, ts, end_ts, bytes, detail)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [.text(serviceId), .text(kind.rawValue), .int(ts), .int(ts), .int(bytes),
             detail.map { Database.Value.text($0) } ?? .null])
        return ServiceEvent(serviceId: serviceId, kind: kind, at: now, bytes: bytes, detail: detail)
    }

    /// Verkehr trotz aktiver Sperre festhalten.
    ///
    /// Zusammengefasst zu Episoden: Bei 2-s-Sampling entstünden sonst 1800
    /// Zeilen pro Stunde, in denen dieselbe Aussage steht. Ein neuer Eintrag
    /// beginnt erst, wenn seit dem letzten `coalesceWithin` Sekunden Ruhe war —
    /// so bleibt der **Beginn** der Episode als Zeitpunkt erhalten.
    public func recordAttempt(serviceId: String, bytes: Int64,
                              at now: Date = Date(),
                              coalesceWithin: TimeInterval = 120) throws {
        let ts = Int64(now.timeIntervalSince1970)
        let recent = try db.query("""
            SELECT id, end_ts FROM service_event
            WHERE service_id = ? AND kind = 'attempt' ORDER BY end_ts DESC LIMIT 1
            """, [.text(serviceId)]) { ($0.int(0), $0.int(1)) }.first

        if let recent, TimeInterval(ts - recent.1) <= coalesceWithin {
            try db.run("UPDATE service_event SET end_ts = ?, bytes = bytes + ? WHERE id = ?",
                       [.int(ts), .int(bytes), .int(recent.0)])
        } else {
            _ = try logEvent(.attempt, serviceId: serviceId, bytes: bytes, at: now)
        }
    }

    public func events(serviceId: String? = nil, since: Date? = nil,
                       kinds: [ServiceEvent.Kind]? = nil, limit: Int = 200) throws -> [ServiceEvent] {
        var sql = """
            SELECT id, service_id, kind, ts, end_ts, bytes, detail FROM service_event WHERE 1 = 1
            """
        var params: [Database.Value] = []
        if let serviceId {
            sql += " AND service_id = ?"
            params.append(.text(serviceId))
        }
        if let since {
            sql += " AND end_ts >= ?"
            params.append(.int(Int64(since.timeIntervalSince1970)))
        }
        if let kinds, !kinds.isEmpty {
            sql += " AND kind IN (" + kinds.map { _ in "?" }.joined(separator: ",") + ")"
            params.append(contentsOf: kinds.map { Database.Value.text($0.rawValue) })
        }
        sql += " ORDER BY ts DESC LIMIT ?"
        params.append(.int(Int64(limit)))

        return try db.query(sql, params) { r in
            ServiceEvent(id: r.int(0), serviceId: r.text(1),
                         kind: ServiceEvent.Kind(rawValue: r.text(2)) ?? .attempt,
                         at: Date(timeIntervalSince1970: TimeInterval(r.int(3))),
                         until: Date(timeIntervalSince1970: TimeInterval(r.int(4))),
                         bytes: r.int(5), detail: r.textOrNil(6))
        }
    }

    public struct AttemptSummary: Sendable {
        public var count: Int
        public var bytes: Int64
        public var last: Date
    }

    /// Verkehr trotz Sperre, verdichtet pro Dienst — eine Abfrage für die
    /// ganze Liste statt einer je Zeile.
    public func attemptSummary(since: Date? = nil) throws -> [String: AttemptSummary] {
        var sql = """
            SELECT service_id, COUNT(*), COALESCE(SUM(bytes), 0), MAX(end_ts)
            FROM service_event WHERE kind = 'attempt'
            """
        var params: [Database.Value] = []
        if let since {
            sql += " AND end_ts >= ?"
            params.append(.int(Int64(since.timeIntervalSince1970)))
        }
        sql += " GROUP BY service_id"

        let rows = try db.query(sql, params) {
            ($0.text(0), Int($0.int(1)), $0.int(2), $0.int(3))
        }
        return Dictionary(uniqueKeysWithValues: rows.map {
            ($0.0, AttemptSummary(count: $0.1, bytes: $0.2,
                                  last: Date(timeIntervalSince1970: TimeInterval($0.3))))
        })
    }

    // MARK: - Mengenverlauf

    /// Verbrauch über die Zeit, in Fenster der Länge `bucket` zerlegt.
    ///
    /// Lücken werden mit Nullen aufgefüllt: Eine Zeitachse, die stille Stunden
    /// überspringt, würde einen gleichmäßigen Verlauf vortäuschen.
    ///
    /// Unterhalb einer Stunde liefern nur die Rohdaten (48 h Aufbewahrung) die
    /// nötige Auflösung — die Stundentabelle ließe sich nicht feiner
    /// aufteilen, ohne Zahlen zu erfinden. Ältere Fenster bleiben dann leer.
    public func history(serviceIds: [String]? = nil, since: Date, until: Date = Date(),
                        bucket: TimeInterval = 3600) throws -> [String: [HistoryBucket]] {
        let step = max(60, Int64(bucket))
        let from = (Int64(since.timeIntervalSince1970) / step) * step
        let to = Int64(until.timeIntervalSince1970)
        guard to >= from else { return [:] }

        var idFilter = ""
        var idParams: [Database.Value] = []
        if let serviceIds {
            guard !serviceIds.isEmpty else { return [:] }
            idFilter = " AND service_id IN (" + serviceIds.map { _ in "?" }.joined(separator: ",") + ")"
            idParams = serviceIds.map { Database.Value.text($0) }
        }

        var sums: [String: [Int64: (Int64, Int64)]] = [:]
        func add(_ id: String, _ bucketStart: Int64, _ bytesIn: Int64, _ bytesOut: Int64) {
            let clamped = max(from, (bucketStart / step) * step)
            sums[id, default: [:]][clamped, default: (0, 0)].0 += bytesIn
            sums[id, default: [:]][clamped, default: (0, 0)].1 += bytesOut
        }

        let compactedUntil = (try? kvInt("compacted_until")) ?? 0

        if step >= 3600 {
            let hourlyTo = min(to, compactedUntil)
            if hourlyTo > from {
                for row in try db.query("""
                    SELECT service_id, (hour / ?) * ?, SUM(bytes_in), SUM(bytes_out)
                    FROM usage_hourly WHERE hour >= ? AND hour < ?\(idFilter)
                    GROUP BY 1, 2
                    """, [.int(step), .int(step), .int(from), .int(hourlyTo)] + idParams,
                    { ($0.text(0), $0.int(1), $0.int(2), $0.int(3)) }) {
                    add(row.0, row.1, row.2, row.3)
                }
            }
        }

        let rawFrom = step >= 3600 ? max(from, compactedUntil) : from
        for row in try db.query("""
            SELECT service_id, (ts / ?) * ?, SUM(bytes_in), SUM(bytes_out)
            FROM sample WHERE ts >= ? AND ts <= ?\(idFilter)
            GROUP BY 1, 2
            """, [.int(step), .int(step), .int(rawFrom), .int(to)] + idParams,
            { ($0.text(0), $0.int(1), $0.int(2), $0.int(3)) }) {
            add(row.0, row.1, row.2, row.3)
        }

        var out: [String: [HistoryBucket]] = [:]
        for (id, byBucket) in sums {
            var series: [HistoryBucket] = []
            var t = from
            while t <= to {
                let value = byBucket[t] ?? (0, 0)
                series.append(HistoryBucket(start: Date(timeIntervalSince1970: TimeInterval(t)),
                                            bytesIn: value.0, bytesOut: value.1))
                t += step
            }
            out[id] = series
        }
        return out
    }

    /// Verlauf eines einzelnen Dienstes, begrenzt auf dessen Zählbeginn.
    public func history(serviceId: String, since: Date, until: Date = Date(),
                        bucket: TimeInterval = 3600) throws -> [HistoryBucket] {
        let trackedStart = try trackedService(id: serviceId)?.firstSeen
        let start = max(since, trackedStart ?? since)
        let series = try history(serviceIds: [serviceId], since: start, until: until, bucket: bucket)
        return series[serviceId] ?? []
    }
}

// MARK: - Zusammengesetzte Liste

extension Store {

    /// Die Dienstliste, wie Oberfläche und CLI sie zeigen: alle je gesehenen
    /// Dienste, gerade aktive zuerst.
    ///
    /// Eine Implementierung für beide Oberflächen — sonst driften Reihenfolge
    /// und Aktivitätsbegriff auseinander, und dieselbe Liste sähe im Fenster
    /// anders aus als im Terminal.
    public func trackedUsage(catalog: ServiceCatalog,
                             rates: [String: Double] = [:],
                             now: Date = Date()) throws -> [ServiceUsage] {
        let tracked = try trackedServices()
        let blocked = try blockedServiceIds()
        let attempts = try attemptSummary()
        let todayRows = try usage(since: Calendar.current.startOfDay(for: now), until: now)
        let today = Dictionary(todayRows.map { ($0.serviceId, $0.total) }, uniquingKeysWith: +)

        var rows = tracked.map { entry -> ServiceUsage in
            let attempt = attempts[entry.serviceId]
            return ServiceUsage(
                service: catalog.serviceOrUnknown(id: entry.serviceId),
                bytesIn: entry.bytesIn, bytesOut: entry.bytesOut,
                rate: rates[entry.serviceId] ?? 0,
                isBlocked: blocked.contains(entry.serviceId),
                todayBytes: today[entry.serviceId] ?? 0,
                firstSeen: entry.firstSeen, lastSeen: entry.lastSeen,
                attemptCount: attempt?.count ?? 0,
                attemptBytes: attempt?.bytes ?? 0,
                lastAttempt: attempt?.last)
        }

        // Dienste, die gerade senden, aber noch keinen Merkposten haben: Der
        // entsteht erst beim Schreiben des Messwerts, die Rate liegt schon
        // vorher vor. Ohne diesen Zusatz fehlte der erste Ausschlag.
        let known = Set(rows.map(\.id))
        for (serviceId, rate) in rates where rate > 0 && !known.contains(serviceId) {
            rows.append(ServiceUsage(
                service: catalog.serviceOrUnknown(id: serviceId),
                bytesIn: 0, bytesOut: 0, rate: rate,
                isBlocked: blocked.contains(serviceId),
                lastSeen: now))
        }

        rows.sort { a, b in
            let (activeA, activeB) = (a.isActive(now: now), b.isActive(now: now))
            if activeA != activeB { return activeA }
            if activeA && a.rate != b.rate { return a.rate > b.rate }
            if a.total != b.total { return a.total > b.total }
            return a.service.name.localizedCaseInsensitiveCompare(b.service.name) == .orderedAscending
        }
        return rows
    }
}
