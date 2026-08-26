import Foundation

/// Wie lange ein Dienst nach der letzten Messung noch als „gerade aktiv" gilt.
///
/// Gemessen wird alle 2 s. Ein Dienst, der in Schüben sendet, wäre bei einem
/// engeren Fenster im Sekundentakt mal aktiv, mal nicht — das Flackern in der
/// Liste wäre schlimmer als die kleine Unschärfe.
public let ActivityWindow: TimeInterval = 60

/// Ein Dienst, der einmal Daten gebraucht hat.
///
/// Anders als `usage(since:)` verschwindet dieser Eintrag nicht, wenn der
/// Dienst eine Weile still ist: Er bleibt stehen, bis der Nutzer die Zählung
/// zurücksetzt. Nur so lässt sich etwas sperren, das gerade nichts tut —
/// und genau das ist der Normalfall, wenn man aufräumen will.
public struct TrackedService: Sendable, Identifiable {
    public var serviceId: String
    /// Beginn der Zählung für diesen Dienst (erste Sichtung bzw. letzter Reset).
    public var firstSeen: Date
    /// Letzte gemessene Aktivität.
    public var lastSeen: Date
    public var bytesIn: Int64
    public var bytesOut: Int64

    public init(serviceId: String, firstSeen: Date, lastSeen: Date,
                bytesIn: Int64, bytesOut: Int64) {
        self.serviceId = serviceId
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }

    public var id: String { serviceId }
    public var total: Int64 { bytesIn + bytesOut }

    public func isActive(now: Date = Date(), window: TimeInterval = ActivityWindow) -> Bool {
        now.timeIntervalSince(lastSeen) <= window
    }
}

/// Ein Eintrag im Protokoll eines Dienstes.
///
/// `attempt` ist der wichtigste: Daten, die trotz gesetzter Sperre geflossen
/// sind. Ob das ein echter Verbindungsversuch war, lässt sich ohne
/// Netzwerkfilter nicht sagen — messbar ist nur, dass Bytes gezählt wurden,
/// während die Sperre stand. Genau das wird protokolliert, nicht mehr.
public struct ServiceEvent: Sendable, Identifiable {
    public enum Kind: String, Sendable, CaseIterable {
        case blocked    // Sperre gesetzt
        case released   // Sperre aufgehoben
        case attempt    // Verkehr trotz aktiver Sperre
        case reset      // Zählung zurückgesetzt

        public var displayName: String {
            switch self {
            case .blocked:  return "gesperrt"
            case .released: return "freigegeben"
            case .attempt:  return "trotz Sperre aktiv"
            case .reset:    return "Zählung zurückgesetzt"
            }
        }
    }

    public var id: Int64
    public var serviceId: String
    public var kind: Kind
    /// Beginn. Bei `attempt` der Anfang der Episode.
    public var at: Date
    /// Ende der Episode; bei Punktereignissen gleich `at`.
    public var until: Date
    public var bytes: Int64
    public var detail: String?

    public init(id: Int64 = 0, serviceId: String, kind: Kind, at: Date,
                until: Date? = nil, bytes: Int64 = 0, detail: String? = nil) {
        self.id = id
        self.serviceId = serviceId
        self.kind = kind
        self.at = at
        self.until = until ?? at
        self.bytes = bytes
        self.detail = detail
    }

    public var isEpisode: Bool { until.timeIntervalSince(at) >= 1 }
}

/// Ein Zeitfenster im Mengenverlauf.
public struct HistoryBucket: Sendable, Identifiable {
    public var start: Date
    public var bytesIn: Int64
    public var bytesOut: Int64

    public init(start: Date, bytesIn: Int64, bytesOut: Int64) {
        self.start = start
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }

    public var id: Double { start.timeIntervalSince1970 }
    public var total: Int64 { bytesIn + bytesOut }
}
