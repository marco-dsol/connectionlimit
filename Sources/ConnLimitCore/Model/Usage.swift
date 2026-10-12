import Foundation

/// Ein roher nettop-Messpunkt für einen Prozess.
public struct ProcessSample: Sendable, Equatable {
    public var name: String
    public var pid: Int32
    public var bytesIn: Int64
    public var bytesOut: Int64

    public init(name: String, pid: Int32, bytesIn: Int64, bytesOut: Int64) {
        self.name = name
        self.pid = pid
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }

    public var key: String { "\(name).\(pid)" }
}

/// Zuwachs zwischen zwei Messpunkten, bereits einem Dienst zugeordnet.
public struct UsageDelta: Sendable {
    public var serviceId: String
    public var bytesIn: Int64
    public var bytesOut: Int64

    public init(serviceId: String, bytesIn: Int64, bytesOut: Int64) {
        self.serviceId = serviceId
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }

    public var total: Int64 { bytesIn + bytesOut }
}

/// Verbrauch eines Dienstes über einen Zeitraum, wie ihn die UI zeigt.
///
/// Trägt zusätzlich das, was die Dauerbeobachtung beisteuert: seit wann der
/// Dienst bekannt ist, wann er zuletzt Daten bewegt hat, und ob trotz Sperre
/// noch etwas durchkam. Damit bleibt eine Zeile auch dann aussagekräftig,
/// wenn der Dienst gerade nichts tut.
public struct ServiceUsage: Sendable, Identifiable {
    public var service: Service
    public var bytesIn: Int64
    public var bytesOut: Int64
    /// Aktuelle Rate in Byte/s, aus dem letzten Sampling-Intervall.
    public var rate: Double
    public var isBlocked: Bool
    /// Verbrauch seit Mitternacht — die Gesamtsumme allein sagt nicht, ob der
    /// Dienst heute noch eine Rolle spielt.
    public var todayBytes: Int64
    public var firstSeen: Date?
    public var lastSeen: Date?
    /// Episoden mit Verkehr trotz aktiver Sperre.
    public var attemptCount: Int
    public var attemptBytes: Int64
    public var lastAttempt: Date?

    public init(service: Service, bytesIn: Int64, bytesOut: Int64,
                rate: Double = 0, isBlocked: Bool = false,
                todayBytes: Int64 = 0, firstSeen: Date? = nil, lastSeen: Date? = nil,
                attemptCount: Int = 0, attemptBytes: Int64 = 0, lastAttempt: Date? = nil) {
        self.service = service
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
        self.rate = rate
        self.isBlocked = isBlocked
        self.todayBytes = todayBytes
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.attemptCount = attemptCount
        self.attemptBytes = attemptBytes
        self.lastAttempt = lastAttempt
    }

    public var id: String { service.id }
    public var total: Int64 { bytesIn + bytesOut }

    /// „Gerade aktiv" — entweder läuft die Messung mit (Rate) oder die letzte
    /// Aktivität liegt innerhalb des Aktivitätsfensters. Beides zusammen,
    /// damit CLI und Oberfläche dasselbe meinen, obwohl nur die Oberfläche
    /// laufend misst.
    public func isActive(now: Date = Date()) -> Bool {
        if rate > 0 { return true }
        guard let lastSeen else { return false }
        return now.timeIntervalSince(lastSeen) <= ActivityWindow
    }

    /// Verkehr trotz Sperre — die Kombination, auf die es ankommt: Die Sperre
    /// steht, und trotzdem fließen Daten.
    public func isLeaking(now: Date = Date()) -> Bool { isBlocked && isActive(now: now) }
}

public enum ByteFormat {
    /// Dezimal (1 kB = 1000 B) — so rechnen Mobilfunktarife ab, und darum
    /// geht es hier.
    public static func short(_ bytes: Int64) -> String {
        let b = Double(bytes)
        switch abs(b) {
        case 0..<1_000:             return "\(bytes) B"
        case 1_000..<1_000_000:     return String(format: "%.1f kB", b / 1_000)
        case 1_000_000..<1_000_000_000: return String(format: "%.1f MB", b / 1_000_000)
        default:                    return String(format: "%.2f GB", b / 1_000_000_000)
        }
    }

    public static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond >= 1 else { return "—" }
        return short(Int64(bytesPerSecond)) + "/s"
    }

    /// Parst "5GB", "500 MB", "1.5 gb", "1,5 GB" → Bytes.
    ///
    /// Das Komma zählt als Dezimaltrenner: Wer „1,5 GB" eintippt, meint
    /// anderthalb Gigabyte — und sollte dafür keine Fehlermeldung bekommen.
    public static func parse(_ text: String) -> Int64? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: ",", with: ".")
        let units: [(String, Double)] = [("gb", 1e9), ("mb", 1e6), ("kb", 1e3), ("g", 1e9), ("m", 1e6), ("k", 1e3), ("b", 1)]
        for (suffix, factor) in units where t.hasSuffix(suffix) {
            let numPart = t.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)
            guard let v = Double(numPart), v >= 0, v.isFinite else { return nil }
            return Int64(v * factor)
        }
        return Double(t).flatMap { $0 >= 0 && $0.isFinite ? Int64($0) : nil }
    }
}
