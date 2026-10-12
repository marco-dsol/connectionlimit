import Foundation

/// Grobe Kategorie eines Dienstes. Profile sperren Klassen, nicht einzelne
/// Dienste — dadurch greifen sie auch für Dienste, die es beim Anlegen des
/// Profils noch gar nicht gab.
public enum ServiceClass: String, Codable, CaseIterable, Sendable {
    case essential
    case update
    case backup
    case telemetry
    case media
    case sync
    case mail
    case browser
    case messaging
    case other

    public var displayName: String {
        switch self {
        case .essential: return L("Systemkritisch")
        case .update:    return L("Updates")
        case .backup:    return L("Backup")
        case .telemetry: return L("Telemetrie")
        case .media:     return L("Medien")
        case .sync:      return L("Cloud-Sync")
        case .mail:      return L("E-Mail")
        case .browser:   return L("Browser")
        case .messaging: return L("Messenger")
        case .other:     return L("Sonstiges")
        }
    }

    /// `essential` ist hart gegen jede Sperre geschützt — über UI, Profil und
    /// Automatik gleichermaßen. Sonst könnte sich das Werkzeug selbst oder das
    /// VPN aussperren.
    public var isBlockable: Bool { self != .essential }
}
