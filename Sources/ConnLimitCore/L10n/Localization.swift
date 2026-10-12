import Foundation

/// Sprache der Oberfläche.
///
/// Deutsch ist die Ausgangssprache: Jeder Text steht im Quelltext auf Deutsch
/// und dient zugleich als Schlüssel in die Übersetzungstabelle. So bleibt der
/// Code lesbar wie bisher, und eine fehlende Übersetzung fällt sichtbar auf
/// Deutsch zurück statt auf einen kryptischen Schlüssel.
public enum Language: String, CaseIterable, Sendable {
    case de, en

    /// Name in der eigenen Sprache — so findet jeder seine wieder, auch wenn
    /// die Oberfläche gerade in der anderen steht.
    public var nativeName: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        }
    }

    public var shortCode: String { rawValue.uppercased() }

    public var locale: Locale {
        switch self {
        case .de: return Locale(identifier: "de_AT")
        case .en: return Locale(identifier: "en_GB")
        }
    }
}

/// Was der Nutzer eingestellt hat. `system` folgt der Sprache von macOS.
public enum LanguagePreference: String, CaseIterable, Sendable {
    case system, de, en
}

public enum L10n {
    /// Schlüssel in den Einstellungen der App. Die Kommandozeile liest
    /// denselben Wert — wer die App auf Englisch stellt, bekommt auch im
    /// Terminal Englisch.
    public static let defaultsKey = "language"

    /// Die gerade geltende Sprache. Wird beim Start einmal aufgelöst und bei
    /// jedem Umschalten neu gesetzt.
    nonisolated(unsafe) public static var language: Language = resolve(storedPreference)

    /// Einstellungen der App. In der App selbst (und im mitgelieferten
    /// `connlimit`, das im selben Bundle liegt) ist das die eigene Domäne;
    /// außerhalb des Bundles — `swift run` — dieselbe Domäne über ihren Namen.
    static var defaults: UserDefaults {
        if Bundle.main.bundleIdentifier == Store.appId { return .standard }
        return UserDefaults(suiteName: Store.appId) ?? .standard
    }

    public static var storedPreference: LanguagePreference {
        defaults.string(forKey: defaultsKey).flatMap(LanguagePreference.init) ?? .system
    }

    public static func setPreference(_ preference: LanguagePreference) {
        if preference == .system {
            defaults.removeObject(forKey: defaultsKey)
        } else {
            defaults.set(preference.rawValue, forKey: defaultsKey)
        }
        language = resolve(preference)
    }

    /// `CONNLIMIT_LANG=en` schlägt alles — für Skripte, die eine feste Sprache
    /// brauchen, und für die Prüfsuite.
    public static func resolve(_ preference: LanguagePreference) -> Language {
        if let forced = ProcessInfo.processInfo.environment["CONNLIMIT_LANG"]
            .flatMap({ Language(rawValue: $0.lowercased()) }) {
            return forced
        }
        switch preference {
        case .de: return .de
        case .en: return .en
        case .system:
            let first = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return first.hasPrefix("de") ? .de : .en
        }
    }

    public static var locale: Locale { language.locale }

    /// Text in der geltenden Sprache.
    /// Die englische Tabelle — für die Prüfsuite, die Platzhalter abgleicht.
    public static var englishTable: [String: String] { Strings.en }

    public static func tr(_ key: String) -> String {
        guard language == .en else { return key }
        return Strings.en[key] ?? key
    }
}

/// Übersetzt einen deutschen Ausgangstext.
public func L(_ key: String) -> String { L10n.tr(key) }

/// Übersetzt und füllt Platzhalter. Alle Platzhalter sind `%@`, bei
/// abweichender Reihenfolge positional (`%1$@`) — Zahlen werden vorher zu
/// Text. Das erspart die Falle, dass `%d` auf 64-Bit-Werten stillschweigend
/// Unsinn ausgibt.
public func L(_ key: String, _ args: CustomStringConvertible...) -> String {
    String(format: L10n.tr(key), arguments: args.map { $0.description as NSString })
}

// MARK: - Zeitangaben

/// Datums- und Zeitformate, die Oberfläche und Kommandozeile teilen.
public enum DisplayTime {
    /// „14:05" — immer 24 Stunden, auch im Englischen: Ein Messwerkzeug liest
    /// sich mit „2:05 PM" nur schlechter.
    public static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// „25.08. 17:01" bzw. „Aug 25 17:01" — feste Breite, damit Spalten im
    /// Terminal stehen bleiben.
    public static func dayAndTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = L10n.language == .de ? "dd.MM. HH:mm" : "MMM dd HH:mm"
        return f.string(from: date)
    }

    /// Heute nur die Uhrzeit, gestern „gestern 21:12", sonst Tag und Uhrzeit.
    public static func stamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return clock(date) }
        if calendar.isDateInYesterday(date) { return L("gestern %@", clock(date)) }
        return dayAndTime(date)
    }

    /// „vor 4 min" / „4 min ago".
    public static func ago(_ date: Date, now: Date = Date()) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return L("vor %@ s", Int(s)) }
        if s < 3600 { return L("vor %@ min", Int(s / 60)) }
        if s < 86400 { return L("vor %@ h", Int(s / 3600)) }
        if s < 7 * 86400 {
            let days = Int(s / 86400)
            return days == 1 ? L("vor 1 Tag") : L("vor %@ Tagen", days)
        }
        return dayAndTime(date)
    }

    /// Restzeit bis `date`: „12 min", „1.5 h", „3 Tage".
    public static func remaining(until date: Date, now: Date = Date()) -> String {
        let s = max(0, date.timeIntervalSince(now))
        if s < 60 { return "\(Int(s)) s" }
        if s < 3600 { return "\(Int(s / 60)) min" }
        if s < 86400 { return String(format: "%.1f h", s / 3600) }
        let days = Int((s / 86400).rounded())
        return days == 1 ? L("1 Tag") : L("%@ Tage", days)
    }
}
