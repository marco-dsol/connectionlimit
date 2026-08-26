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
        case .essential: return "Systemkritisch"
        case .update:    return "Updates"
        case .backup:    return "Backup"
        case .telemetry: return "Telemetrie"
        case .media:     return "Medien"
        case .sync:      return "Cloud-Sync"
        case .mail:      return "E-Mail"
        case .browser:   return "Browser"
        case .messaging: return "Messenger"
        case .other:     return "Sonstiges"
        }
    }

    /// `essential` ist hart gegen jede Sperre geschützt — über UI, Profil und
    /// Automatik gleichermaßen. Sonst könnte sich das Werkzeug selbst oder das
    /// VPN aussperren.
    public var isBlockable: Bool { self != .essential }
}
