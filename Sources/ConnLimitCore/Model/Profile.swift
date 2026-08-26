import Foundation

/// Eskalationsstufen. Höhere Stufe sperrt alles der niedrigeren plus mehr.
public enum PolicyTier: Int, Codable, CaseIterable, Comparable, Sendable {
    case off = 0
    case frugal = 1      // "Sparsam"      — kostet keinen Komfort
    case vacation = 2    // "Urlaubsmodus" — Default in teuren Netzen
    case emergency = 3   // "Notfall"      — Budget fast weg

    public static func < (a: PolicyTier, b: PolicyTier) -> Bool { a.rawValue < b.rawValue }

    public var displayName: String {
        switch self {
        case .off:       return "Aus"
        case .frugal:    return "Sparsam"
        case .vacation:  return "Urlaubsmodus"
        case .emergency: return "Notfall"
        }
    }

    public var summary: String {
        switch self {
        case .off:       return "keine Sperren"
        case .frugal:    return "Updates, Backups, Telemetrie, Medien"
        case .vacation:  return "zusätzlich Cloud-Sync"
        case .emergency: return "zusätzlich E-Mail und Browser"
        }
    }

    /// Klassen, die auf dieser Stufe ab Werk gesperrt werden.
    ///
    /// Der Nutzer kann das je Stufe überschreiben — die geltende Belegung
    /// liefert `PolicyState.blockedClasses(for:)`, nicht diese Eigenschaft.
    public var defaultBlockedClasses: Set<ServiceClass> {
        switch self {
        case .off:
            return []
        case .frugal:
            return [.update, .backup, .telemetry, .media]
        case .vacation:
            return PolicyTier.frugal.defaultBlockedClasses.union([.sync])
        case .emergency:
            return PolicyTier.vacation.defaultBlockedClasses.union([.mail, .browser])
        }
    }

    /// „Aus" bedeutet aus. Diese Stufe ist bewusst nicht editierbar — sonst
    /// gäbe es keinen Zustand mehr, auf den man sich zurückziehen kann.
    public var isEditable: Bool { self != .off }
}

/// Persistenter Zustand der Policy.
public struct PolicyState: Codable, Sendable {
    /// Vom Nutzer gewählte Stufe. `nil` = der Netzklasse folgen.
    public var manualTier: PolicyTier?
    /// Automatisch nach Netzklasse umschalten?
    public var followNetwork: Bool
    /// Automatisch eskalieren, wenn das Budget aus dem Ruder läuft?
    public var autoEscalate: Bool
    /// Dienste, die auch bei aktivem Profil erlaubt bleiben (dauerhaft).
    public var alwaysAllow: Set<String>
    /// Dienste, die immer gesperrt sind, unabhängig vom Profil.
    public var alwaysBlock: Set<String>
    /// Eigene Belegung je Stufe. Schlüssel ist `PolicyTier.rawValue` als Text,
    /// weil JSON keine Zahlen als Objektschlüssel kennt. Fehlt ein Eintrag,
    /// gilt die Voreinstellung — so bleiben ältere Datenbanken lesbar.
    public var customTiers: [String: Set<ServiceClass>]

    public init(manualTier: PolicyTier? = nil, followNetwork: Bool = true,
                autoEscalate: Bool = true, alwaysAllow: Set<String> = [],
                alwaysBlock: Set<String> = [], customTiers: [String: Set<ServiceClass>] = [:]) {
        self.manualTier = manualTier
        self.followNetwork = followNetwork
        self.autoEscalate = autoEscalate
        self.alwaysAllow = alwaysAllow
        self.alwaysBlock = alwaysBlock
        self.customTiers = customTiers
    }

    private enum CodingKeys: String, CodingKey {
        case manualTier, followNetwork, autoEscalate, alwaysAllow, alwaysBlock, customTiers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        manualTier = try c.decodeIfPresent(PolicyTier.self, forKey: .manualTier)
        followNetwork = try c.decodeIfPresent(Bool.self, forKey: .followNetwork) ?? true
        autoEscalate = try c.decodeIfPresent(Bool.self, forKey: .autoEscalate) ?? true
        alwaysAllow = try c.decodeIfPresent(Set<String>.self, forKey: .alwaysAllow) ?? []
        alwaysBlock = try c.decodeIfPresent(Set<String>.self, forKey: .alwaysBlock) ?? []
        customTiers = try c.decodeIfPresent([String: Set<ServiceClass>].self, forKey: .customTiers) ?? [:]
    }

    // MARK: - Editierbare Stufen

    /// Die Klassen, die auf dieser Stufe tatsächlich gesperrt werden.
    ///
    /// `essential` wird hier ein zweites Mal herausgenommen. Der Enforcer
    /// weigert sich ohnehin, aber eine gespeicherte Belegung, die VPN und DNS
    /// zu sperren verspricht, wäre schon als Anzeige eine Lüge.
    public func blockedClasses(for tier: PolicyTier) -> Set<ServiceClass> {
        guard tier.isEditable else { return [] }
        let base = customTiers[String(tier.rawValue)] ?? tier.defaultBlockedClasses
        return base.filter(\.isBlockable)
    }

    public func isCustomized(_ tier: PolicyTier) -> Bool {
        guard let custom = customTiers[String(tier.rawValue)] else { return false }
        return custom.filter(\.isBlockable) != tier.defaultBlockedClasses
    }

    public mutating func setBlockedClasses(_ classes: Set<ServiceClass>, for tier: PolicyTier) {
        guard tier.isEditable else { return }
        customTiers[String(tier.rawValue)] = classes.filter(\.isBlockable)
    }

    public mutating func resetTier(_ tier: PolicyTier) {
        customTiers.removeValue(forKey: String(tier.rawValue))
    }

    /// Kurzbeschreibung der Stufe — bei eigener Belegung aus den Klassen
    /// gebildet, sonst der eingebaute Text.
    public func summary(for tier: PolicyTier) -> String {
        guard isCustomized(tier) else { return tier.summary }
        let classes = blockedClasses(for: tier)
        guard !classes.isEmpty else { return "keine Sperren" }
        return ServiceClass.allCases.filter { classes.contains($0) }
            .map(\.displayName).joined(separator: ", ")
    }

    /// Stufen, die weniger sperren als eine niedrigere.
    ///
    /// Die Budget-Automatik stuft nur nach oben. Wenn „Notfall" weniger sperrt
    /// als „Sparsam", lockert eine Eskalation — das ist fast nie gewollt, und
    /// die Oberfläche muss es sagen dürfen, statt es stillschweigend zu
    /// verbiegen.
    public var inconsistentTiers: [PolicyTier] {
        var result: [PolicyTier] = []
        let ordered = PolicyTier.allCases.filter(\.isEditable).sorted()
        for (index, tier) in ordered.enumerated() {
            let mine = blockedClasses(for: tier)
            for lower in ordered.prefix(index) where !blockedClasses(for: lower).isSubset(of: mine) {
                result.append(tier)
                break
            }
        }
        return result
    }
}

public struct Budget: Codable, Sendable {
    public var totalBytes: Int64
    public var startsAt: Date
    public var endsAt: Date
    public var label: String

    public init(totalBytes: Int64, startsAt: Date, endsAt: Date, label: String = "Reise") {
        self.totalBytes = totalBytes
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.label = label
    }
}

public struct BudgetStatus: Sendable {
    public var budget: Budget
    public var usedBytes: Int64
    public var usedTodayBytes: Int64

    public init(budget: Budget, usedBytes: Int64, usedTodayBytes: Int64) {
        self.budget = budget
        self.usedBytes = usedBytes
        self.usedTodayBytes = usedTodayBytes
    }

    public var remainingBytes: Int64 { max(0, budget.totalBytes - usedBytes) }
    public var remainingFraction: Double {
        guard budget.totalBytes > 0 else { return 0 }
        return Double(remainingBytes) / Double(budget.totalBytes)
    }

    public var remainingDays: Double {
        max(0.0, budget.endsAt.timeIntervalSince(Date()) / 86_400)
    }

    /// Was heute noch zur Verfügung steht, wenn der Rest gleichmäßig verteilt wird.
    public var dailyAllowance: Int64 {
        let days = max(1.0, remainingDays.rounded(.up))
        return Int64(Double(remainingBytes) / days)
    }

    /// Hochrechnung des heutigen Verbrauchs auf den ganzen Tag.
    public var projectedToday: Int64 {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let elapsed = Date().timeIntervalSince(startOfDay)
        guard elapsed > 600 else { return usedTodayBytes }  // erste 10 min sind Rauschen
        return Int64(Double(usedTodayBytes) * 86_400 / elapsed)
    }

    public enum Light: String, Sendable { case green, yellow, red }

    public var light: Light {
        let allowance = dailyAllowance
        guard allowance > 0 else { return .red }
        let ratio = Double(projectedToday) / Double(allowance)
        if ratio <= 1.0 { return .green }
        if ratio <= 1.3 { return .yellow }
        return .red
    }
}
