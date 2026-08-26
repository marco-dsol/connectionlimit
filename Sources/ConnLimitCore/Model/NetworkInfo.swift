import Foundation

/// Wie teuer ist das aktuelle Netz?
public enum NetworkClass: String, Codable, CaseIterable, Sendable {
    /// Heim-WLAN, Büro, LAN — keine Sperren, zählt nicht aufs Budget.
    case free
    /// Hotspot, Roaming, Volumentarif — Profil greift, Verbrauch zählt.
    case metered
    /// Langsam oder teuer, aber nicht kritisch — nur harte Fresser gesperrt.
    case limited
    /// Neu gesehen — es wird gefragt, bis dahin wie `limited` behandelt.
    case unknown

    public var displayName: String {
        switch self {
        case .free:    return "frei"
        case .metered: return "teuer"
        case .limited: return "begrenzt"
        case .unknown: return "unbekannt"
        }
    }

    /// Zählt Traffic in diesem Netz gegen das Reisebudget?
    public var countsAgainstBudget: Bool { self == .metered || self == .limited }

    /// Stufe, die beim Wechsel in dieses Netz automatisch greift.
    ///
    /// `unknown` sperrt bewusst **nichts**. Beim ersten Start ist jedes Netz
    /// unbekannt — auch das Heim-WLAN. Dort ungefragt Dienste einzufrieren
    /// wäre genau die Art Überraschung, die ein Werkzeug mit solchen
    /// Befugnissen sich nicht leisten darf. Erst einstufen, dann sperren.
    public var defaultTier: PolicyTier {
        switch self {
        case .free:    return .off
        case .limited: return .frugal
        case .metered: return .vacation
        case .unknown: return .off
        }
    }
}

public enum LinkType: String, Codable, Sendable {
    case wifi, wired, other

    /// Argument für `nettop -t`. Immer typgefiltert sampeln — sonst zählt
    /// Traffic bei aktivem VPN doppelt (einmal auf utun*, einmal physisch).
    public var nettopFilter: String {
        switch self {
        case .wifi:  return "wifi"
        case .wired: return "wired"
        case .other: return "external"
        }
    }
}

/// Ein wiedererkanntes Netz. Die Identität kommt aus der Gateway-MAC —
/// die ist ohne Ortungsdienste-Berechtigung lesbar, im Gegensatz zur SSID.
public struct NetworkIdentity: Codable, Sendable, Equatable {
    public var id: String
    public var interface: String
    public var linkType: LinkType
    public var gatewayIP: String
    public var gatewayMAC: String?
    public var label: String

    public init(id: String, interface: String, linkType: LinkType,
                gatewayIP: String, gatewayMAC: String?, label: String) {
        self.id = id
        self.interface = interface
        self.linkType = linkType
        self.gatewayIP = gatewayIP
        self.gatewayMAC = gatewayMAC
        self.label = label
    }

    /// Kein Netz erreichbar.
    public static let offline = NetworkIdentity(
        id: "offline", interface: "-", linkType: .other,
        gatewayIP: "-", gatewayMAC: nil, label: "Offline")

    public var isOffline: Bool { id == "offline" }
}

public struct NetworkRecord: Codable, Sendable {
    public var identity: NetworkIdentity
    public var networkClass: NetworkClass
    public var firstSeen: Date
    public var lastSeen: Date

    public init(identity: NetworkIdentity, networkClass: NetworkClass,
                firstSeen: Date, lastSeen: Date) {
        self.identity = identity
        self.networkClass = networkClass
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}
