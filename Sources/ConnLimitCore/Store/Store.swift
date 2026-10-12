import Foundation

/// Persistenz für Messdaten, Netze, Sperren und Einstellungen.
public final class Store {
    public let db: Database
    public static let appId = "at.mitsol.connectionlimit"

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(appId, isDirectory: true)
    }
    public static var defaultPath: String {
        defaultDirectory.appendingPathComponent("connlimit.db").path
    }
    public static var catalogPath: URL {
        defaultDirectory.appendingPathComponent("catalog.json")
    }

    public init(path: String = Store.defaultPath) throws {
        db = try Database(path: path)
        try migrate()
    }

    private func migrate() throws {
        try db.exec("""
        CREATE TABLE IF NOT EXISTS sample (
          ts INTEGER NOT NULL, service_id TEXT NOT NULL,
          bytes_in INTEGER NOT NULL, bytes_out INTEGER NOT NULL,
          network_id TEXT NOT NULL, network_class TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS sample_ts ON sample(ts);
        CREATE INDEX IF NOT EXISTS sample_svc ON sample(service_id, ts);

        CREATE TABLE IF NOT EXISTS usage_hourly (
          hour INTEGER NOT NULL, service_id TEXT NOT NULL, network_class TEXT NOT NULL,
          bytes_in INTEGER NOT NULL, bytes_out INTEGER NOT NULL,
          PRIMARY KEY (hour, service_id, network_class)
        );

        CREATE TABLE IF NOT EXISTS network (
          id TEXT PRIMARY KEY, label TEXT NOT NULL, class TEXT NOT NULL,
          gateway_ip TEXT, gateway_mac TEXT, interface TEXT, link_type TEXT,
          first_seen INTEGER NOT NULL, last_seen INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS receipt (
          id TEXT PRIMARY KEY, service_id TEXT NOT NULL, lever TEXT NOT NULL,
          payload TEXT NOT NULL, created_at INTEGER NOT NULL,
          expires_at INTEGER, network_id TEXT, reason TEXT NOT NULL DEFAULT 'manual'
        );

        CREATE TABLE IF NOT EXISTS grant_window (
          id TEXT PRIMARY KEY, service_id TEXT NOT NULL,
          until INTEGER NOT NULL, bytes_at_start INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT NOT NULL);

        -- Dauerbeobachtung: wer einmal Daten gebraucht hat, bleibt in der
        -- Liste stehen, bis der Nutzer zurücksetzt. Eigene Tabelle statt einer
        -- Ableitung aus `sample`, weil die Rohdaten nach 48 h wegfallen — der
        -- Eintrag soll aber bleiben.
        CREATE TABLE IF NOT EXISTS tracked_service (
          service_id TEXT PRIMARY KEY,
          first_seen INTEGER NOT NULL, last_seen INTEGER NOT NULL,
          bytes_in INTEGER NOT NULL DEFAULT 0, bytes_out INTEGER NOT NULL DEFAULT 0
        );

        -- Protokoll: Zeitpunkte von Sperre, Freigabe und Verkehr trotz Sperre.
        CREATE TABLE IF NOT EXISTS service_event (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          service_id TEXT NOT NULL, kind TEXT NOT NULL,
          ts INTEGER NOT NULL, end_ts INTEGER NOT NULL,
          bytes INTEGER NOT NULL DEFAULT 0, detail TEXT
        );
        CREATE INDEX IF NOT EXISTS service_event_svc ON service_event(service_id, ts);
        CREATE INDEX IF NOT EXISTS service_event_ts ON service_event(ts);
        """)

        try backfillTracking()
    }

    // MARK: - Messdaten

    public func record(deltas: [UsageDelta], at date: Date,
                       network: NetworkIdentity, networkClass: NetworkClass) throws {
        guard !deltas.isEmpty else { return }
        let ts = Int64(date.timeIntervalSince1970)
        try db.transaction {
            for d in deltas {
                try db.run("""
                    INSERT INTO sample (ts, service_id, bytes_in, bytes_out, network_id, network_class)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    [.int(ts), .text(d.serviceId), .int(d.bytesIn), .int(d.bytesOut),
                     .text(network.id), .text(networkClass.rawValue)])

                // Dauerbeobachtung fortschreiben. In derselben Transaktion, damit
                // Messwert und Merkposten nicht auseinanderlaufen können.
                guard d.total > 0 else { continue }
                try db.run("""
                    INSERT INTO tracked_service (service_id, first_seen, last_seen, bytes_in, bytes_out)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(service_id) DO UPDATE SET
                      last_seen = excluded.last_seen,
                      bytes_in  = bytes_in  + excluded.bytes_in,
                      bytes_out = bytes_out + excluded.bytes_out
                    """,
                    [.text(d.serviceId), .int(ts), .int(ts), .int(d.bytesIn), .int(d.bytesOut)])
            }
        }
    }

    public struct UsageRow: Sendable {
        public var serviceId: String
        public var bytesIn: Int64
        public var bytesOut: Int64
        public var total: Int64 { bytesIn + bytesOut }
    }

    /// Verbrauch pro Dienst seit `since`. Fasst Rohdaten und stündliche
    /// Verdichtung zusammen, damit auch Zeiträume jenseits der Rohdaten-
    /// Aufbewahrung korrekt sind.
    public func usage(since: Date, until: Date = Date(),
                      networkClasses: Set<NetworkClass>? = nil) throws -> [UsageRow] {
        let from = Int64(since.timeIntervalSince1970)
        let to = Int64(until.timeIntervalSince1970)
        let classFilter = networkClasses.map { set in
            " AND network_class IN (" + set.map { "'\($0.rawValue)'" }.joined(separator: ",") + ")"
        } ?? ""

        // Rohdaten decken alles ab, was noch nicht verdichtet wurde.
        let compactedUntil = (try? kvInt("compacted_until")) ?? 0
        var totals: [String: (Int64, Int64)] = [:]

        // Die Stundentabelle deckt alles bis zum Verdichtungsstand ab, die
        // Rohdaten alles danach — so zählt der Überlappungsbereich nur einmal.
        let hourlyTo = min(to, compactedUntil)
        if hourlyTo > from {
            let rows = try db.query("""
                SELECT service_id, SUM(bytes_in), SUM(bytes_out) FROM usage_hourly
                WHERE hour >= ? AND hour < ?\(classFilter)
                GROUP BY service_id
                """, [.int(from), .int(hourlyTo)]) {
                ($0.text(0), $0.int(1), $0.int(2))
            }
            for (id, bi, bo) in rows {
                totals[id, default: (0, 0)].0 += bi
                totals[id, default: (0, 0)].1 += bo
            }
        }

        let rawFrom = max(from, compactedUntil)
        if to >= rawFrom {
            // Obere Grenze inklusiv: `ts` hat Sekundenauflösung, und `until`
            // ist im Normalfall genau jetzt. Mit `<` fiele alles aus der
            // laufenden Sekunde heraus — bei 2-s-Sampling wäre das der halbe
            // jüngste Messwert.
            let rows = try db.query("""
                SELECT service_id, SUM(bytes_in), SUM(bytes_out) FROM sample
                WHERE ts >= ? AND ts <= ?\(classFilter)
                GROUP BY service_id
                """, [.int(rawFrom), .int(to)]) {
                ($0.text(0), $0.int(1), $0.int(2))
            }
            for (id, bi, bo) in rows {
                totals[id, default: (0, 0)].0 += bi
                totals[id, default: (0, 0)].1 += bo
            }
        }

        return totals.map { UsageRow(serviceId: $0.key, bytesIn: $0.value.0, bytesOut: $0.value.1) }
                     .sorted { $0.total > $1.total }
    }

    public func totalBytes(since: Date, networkClasses: Set<NetworkClass>? = nil) throws -> Int64 {
        try usage(since: since, networkClasses: networkClasses).reduce(0) { $0 + $1.total }
    }

    /// Gesamtverbrauch eines einzelnen Dienstes. Eigene Abfrage statt Filtern
    /// über `usage(since:)` — die Timer-Auswertung ruft das im 30-s-Takt auf.
    public func serviceTotal(_ serviceId: String, since: Date = Date(timeIntervalSince1970: 0)) throws -> Int64 {
        let from = Int64(since.timeIntervalSince1970)
        let compactedUntil = (try? kvInt("compacted_until")) ?? 0
        let hourly = try db.query(
            "SELECT COALESCE(SUM(bytes_in + bytes_out), 0) FROM usage_hourly WHERE service_id = ? AND hour >= ?",
            [.text(serviceId), .int(from)]) { $0.int(0) }.first ?? 0
        // Rohdaten decken alles ab dem Verdichtungsstand ab, die Stundentabelle
        // alles davor — sonst würde der Überlappungsbereich doppelt zählen.
        let rawOnly = try db.query(
            "SELECT COALESCE(SUM(bytes_in + bytes_out), 0) FROM sample WHERE service_id = ? AND ts >= ?",
            [.text(serviceId), .int(max(from, compactedUntil))]) { $0.int(0) }.first ?? 0
        return hourly + rawOnly
    }

    /// Rohdaten stündlich verdichten und nach `rawRetention` löschen.
    public func compact(rawRetention: TimeInterval = 48 * 3600,
                        eventRetention: TimeInterval = 30 * 86400,
                        now: Date = Date()) throws {
        let cutoffHour = Int64(now.addingTimeInterval(-3600).timeIntervalSince1970 / 3600) * 3600
        let alreadyDone = (try? kvInt("compacted_until")) ?? 0
        guard cutoffHour > alreadyDone else { return }

        try db.transaction {
            try db.run("""
                INSERT INTO usage_hourly (hour, service_id, network_class, bytes_in, bytes_out)
                SELECT (ts / 3600) * 3600, service_id, network_class, SUM(bytes_in), SUM(bytes_out)
                FROM sample WHERE ts >= ? AND ts < ?
                GROUP BY 1, 2, 3
                ON CONFLICT(hour, service_id, network_class) DO UPDATE SET
                  bytes_in = bytes_in + excluded.bytes_in,
                  bytes_out = bytes_out + excluded.bytes_out
                """, [.int(alreadyDone), .int(cutoffHour)])
            try setKV("compacted_until", String(cutoffHour))
        }

        let purgeBefore = Int64(now.addingTimeInterval(-rawRetention).timeIntervalSince1970)
        try db.run("DELETE FROM sample WHERE ts < ?", [.int(purgeBefore)])

        // Das Protokoll wächst sonst unbegrenzt. 30 Tage decken jede Reise ab.
        let eventCutoff = Int64(now.addingTimeInterval(-eventRetention).timeIntervalSince1970)
        try db.run("DELETE FROM service_event WHERE end_ts < ?", [.int(eventCutoff)])
    }

    // MARK: - Netze

    public func upsertNetwork(_ identity: NetworkIdentity, class cls: NetworkClass,
                              now: Date = Date()) throws {
        let ts = Int64(now.timeIntervalSince1970)
        try db.run("""
            INSERT INTO network (id, label, class, gateway_ip, gateway_mac, interface, link_type, first_seen, last_seen)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET last_seen = excluded.last_seen
            """,
            [.text(identity.id), .text(identity.label), .text(cls.rawValue),
             .text(identity.gatewayIP), identity.gatewayMAC.map { Database.Value.text($0) } ?? .null,
             .text(identity.interface), .text(identity.linkType.rawValue), .int(ts), .int(ts)])
    }

    public func networkClass(for id: String) throws -> NetworkClass? {
        try db.query("SELECT class FROM network WHERE id = ?", [.text(id)]) {
            NetworkClass(rawValue: $0.text(0))
        }.compactMap { $0 }.first
    }

    public func setNetworkClass(_ cls: NetworkClass, for id: String) throws {
        try db.run("UPDATE network SET class = ? WHERE id = ?", [.text(cls.rawValue), .text(id)])
    }

    public func setNetworkLabel(_ label: String, for id: String) throws {
        try db.run("UPDATE network SET label = ? WHERE id = ?", [.text(label), .text(id)])
    }

    public func allNetworks() throws -> [NetworkRecord] {
        try db.query("""
            SELECT id, label, class, gateway_ip, gateway_mac, interface, link_type, first_seen, last_seen
            FROM network ORDER BY last_seen DESC
            """) { r in
            NetworkRecord(
                identity: NetworkIdentity(
                    id: r.text(0), interface: r.text(5),
                    linkType: LinkType(rawValue: r.text(6)) ?? .other,
                    gatewayIP: r.text(3), gatewayMAC: r.textOrNil(4), label: r.text(1)),
                networkClass: NetworkClass(rawValue: r.text(2)) ?? .unknown,
                firstSeen: Date(timeIntervalSince1970: TimeInterval(r.int(7))),
                lastSeen: Date(timeIntervalSince1970: TimeInterval(r.int(8))))
        }
    }

    // MARK: - Quittungen

    public func save(_ receipt: EnforcementReceipt) throws {
        let payload = String(data: try JSONEncoder().encode(receipt.payload), encoding: .utf8) ?? "{}"
        try db.run("""
            INSERT INTO receipt (id, service_id, lever, payload, created_at, expires_at, network_id, reason)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET payload = excluded.payload,
              expires_at = excluded.expires_at, reason = excluded.reason
            """,
            [.text(receipt.id), .text(receipt.serviceId), .text(receipt.lever.rawValue),
             .text(payload), .int(Int64(receipt.createdAt.timeIntervalSince1970)),
             receipt.expiresAt.map { Database.Value.int(Int64($0.timeIntervalSince1970)) } ?? .null,
             receipt.networkId.map { Database.Value.text($0) } ?? .null,
             .text(receipt.reason.rawValue)])
    }

    public func deleteReceipt(id: String) throws {
        try db.run("DELETE FROM receipt WHERE id = ?", [.text(id)])
    }

    public func openReceipts() throws -> [EnforcementReceipt] {
        try db.query("""
            SELECT id, service_id, lever, payload, created_at, expires_at, network_id, reason
            FROM receipt ORDER BY created_at
            """) { r -> EnforcementReceipt? in
            guard let lever = LeverKind(rawValue: r.text(2)),
                  let payloadData = r.text(3).data(using: .utf8),
                  let payload = try? JSONDecoder().decode(EnforcementReceipt.Payload.self, from: payloadData)
            else { return nil }
            return EnforcementReceipt(
                id: r.text(0), serviceId: r.text(1), lever: lever, payload: payload,
                createdAt: Date(timeIntervalSince1970: TimeInterval(r.int(4))),
                expiresAt: r.intOrNil(5).map { Date(timeIntervalSince1970: TimeInterval($0)) },
                networkId: r.textOrNil(6),
                reason: EnforcementReceipt.Reason(rawValue: r.text(7)) ?? .manual)
        }.compactMap { $0 }
    }

    // MARK: - Freigaben auf Zeit

    public func save(_ grant: Grant) throws {
        try db.run("""
            INSERT INTO grant_window (id, service_id, until, bytes_at_start) VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET until = excluded.until
            """,
            [.text(grant.id), .text(grant.serviceId),
             .int(Int64(grant.until.timeIntervalSince1970)), .int(grant.bytesAtStart)])
    }

    public func deleteGrant(id: String) throws {
        try db.run("DELETE FROM grant_window WHERE id = ?", [.text(id)])
    }

    public func grants() throws -> [Grant] {
        try db.query("SELECT id, service_id, until, bytes_at_start FROM grant_window") {
            Grant(id: $0.text(0), serviceId: $0.text(1),
                  until: Date(timeIntervalSince1970: TimeInterval($0.int(2))),
                  bytesAtStart: $0.int(3))
        }
    }

    // MARK: - Einstellungen

    public func setKV(_ key: String, _ value: String) throws {
        try db.run("INSERT INTO kv (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                   [.text(key), .text(value)])
    }

    public func kv(_ key: String) throws -> String? {
        try db.query("SELECT value FROM kv WHERE key = ?", [.text(key)]) { $0.text(0) }.first
    }

    func kvInt(_ key: String) throws -> Int64 {
        Int64(try kv(key) ?? "") ?? 0
    }

    public func codable<T: Codable>(_ key: String, as type: T.Type) throws -> T? {
        guard let raw = try kv(key), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    public func setCodable<T: Codable>(_ key: String, _ value: T?) throws {
        guard let value else {
            try db.run("DELETE FROM kv WHERE key = ?", [.text(key)])
            return
        }
        let data = try JSONEncoder().encode(value)
        try setKV(key, String(data: data, encoding: .utf8) ?? "")
    }

    public var policyState: PolicyState {
        get { (try? codable("policy", as: PolicyState.self)) .flatMap { $0 } ?? PolicyState() }
    }

    public func savePolicyState(_ state: PolicyState) throws {
        try setCodable("policy", state)
    }

    public var budget: Budget? {
        (try? codable("budget", as: Budget.self)).flatMap { $0 }
    }

    public func saveBudget(_ budget: Budget?) throws {
        try setCodable("budget", budget)
    }
}
