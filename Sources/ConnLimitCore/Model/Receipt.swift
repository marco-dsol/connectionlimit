import Foundation

/// Beleg über eine aktive Sperre. Enthält alles, was zum Rückgängigmachen
/// nötig ist.
///
/// Die Quittung wird **vor** dem Eingriff geschrieben. Ein Absturz dazwischen
/// hinterlässt dann eine wirkungslose Quittung (harmlos, Recovery räumt sie als
/// No-op weg). Andersherum bliebe eine Wirkung ohne Quittung zurück — also eine
/// für immer eingefrorene App. Deshalb ist die Reihenfolge nicht verhandelbar.
public struct EnforcementReceipt: Codable, Sendable, Identifiable {
    public var id: String
    public var serviceId: String
    public var lever: LeverKind
    public var payload: Payload
    public var createdAt: Date
    /// Timer-Sperren laufen automatisch ab.
    public var expiresAt: Date?
    /// Netz, in dem die Sperre gesetzt wurde. Beim Netzwechsel neu bewerten.
    public var networkId: String?
    public var reason: Reason

    public enum Reason: String, Codable, Sendable {
        case profile     // aus dem aktiven Profil
        case manual      // vom Nutzer einzeln gesetzt
        case timer       // befristete Sperre
        case budget      // automatische Eskalation

        public var displayName: String {
            switch self {
            case .profile: return L("durch Profil")
            case .manual:  return L("manuell")
            case .timer:   return L("befristet")
            case .budget:  return L("Budget-Automatik")
            }
        }
    }

    public struct Payload: Codable, Sendable {
        public var pids: [Int32]
        public var jobs: [String]
        public var anchorRule: String?
        public var resumeCommand: [String]?

        public init(pids: [Int32] = [], jobs: [String] = [],
                    anchorRule: String? = nil, resumeCommand: [String]? = nil) {
            self.pids = pids
            self.jobs = jobs
            self.anchorRule = anchorRule
            self.resumeCommand = resumeCommand
        }
    }

    public init(id: String = UUID().uuidString, serviceId: String, lever: LeverKind,
                payload: Payload, createdAt: Date = Date(), expiresAt: Date? = nil,
                networkId: String? = nil, reason: Reason = .manual) {
        self.id = id
        self.serviceId = serviceId
        self.lever = lever
        self.payload = payload
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.networkId = networkId
        self.reason = reason
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}

/// Befristete Ausnahme: Dienst ist trotz Profil erlaubt, bis `until`.
public struct Grant: Codable, Sendable, Identifiable {
    public var id: String
    public var serviceId: String
    public var until: Date
    /// Zählerstand bei Beginn, um hinterher sagen zu können, was die Freigabe
    /// gekostet hat — das ist der eigentliche Lerneffekt.
    public var bytesAtStart: Int64

    public init(id: String = UUID().uuidString, serviceId: String,
                until: Date, bytesAtStart: Int64) {
        self.id = id
        self.serviceId = serviceId
        self.until = until
        self.bytesAtStart = bytesAtStart
    }

    public var isExpired: Bool { until <= Date() }
}
