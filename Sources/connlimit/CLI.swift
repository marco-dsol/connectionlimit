import Foundation
import ConnLimitCore

struct Args {
    private(set) var positional: [String] = []
    private var flags: [String: String] = [:]
    private var switches: Set<String> = []

    init(_ raw: [String]) {
        var i = 0
        while i < raw.count {
            let arg = raw[i]
            if arg.hasPrefix("--") {
                let name = String(arg.dropFirst(2))
                if let eq = name.firstIndex(of: "=") {
                    flags[String(name[name.startIndex..<eq])] = String(name[name.index(after: eq)...])
                } else if i + 1 < raw.count && !raw[i + 1].hasPrefix("--") {
                    flags[name] = raw[i + 1]
                    i += 1
                } else {
                    switches.insert(name)
                }
            } else if arg.hasPrefix("-") && arg.count == 2 {
                switches.insert(String(arg.dropFirst()))
            } else {
                positional.append(arg)
            }
            i += 1
        }
    }

    func value(_ name: String) -> String? { flags[name] }
    func has(_ names: String...) -> Bool { names.contains { switches.contains($0) || flags[$0] != nil } }
    func flag(_ names: String...) -> Bool { names.contains { switches.contains($0) } }
    subscript(_ index: Int) -> String? { index < positional.count ? positional[index] : nil }
}

enum Term {
    static let isTTY = isatty(STDOUT_FILENO) == 1
    static func style(_ s: String, _ code: String) -> String {
        isTTY ? "\u{1B}[\(code)m\(s)\u{1B}[0m" : s
    }
    static func bold(_ s: String) -> String { style(s, "1") }
    static func dim(_ s: String) -> String { style(s, "2") }
    static func red(_ s: String) -> String { style(s, "31") }
    static func green(_ s: String) -> String { style(s, "32") }
    static func yellow(_ s: String) -> String { style(s, "33") }
    static func blue(_ s: String) -> String { style(s, "34") }

    static func pad(_ s: String, _ width: Int) -> String {
        let visible = s.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "",
                                             options: .regularExpression).count
        return s + String(repeating: " ", count: max(0, width - visible))
    }
    /// Kürzt auf die Spaltenbreite. Ohne das schiebt ein langer Dienstname die
    /// ganze Tabelle auseinander — und Namen wie „Microsoft Update &
    /// Telemetrie" sind der Normalfall, nicht die Ausnahme.
    static func fit(_ s: String, _ width: Int) -> String {
        guard s.count > width else { return pad(s, width) }
        return String(s.prefix(max(1, width - 2))) + "… "
    }

    static func padLeft(_ s: String, _ width: Int) -> String {
        let visible = s.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "",
                                             options: .regularExpression).count
        return String(repeating: " ", count: max(0, width - visible)) + s
    }
}

enum CLIError: Error, LocalizedError {
    case usage(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .usage(let m):    return m
        case .notFound(let m): return m
        }
    }
}

enum Parse {
    /// "30m", "2h", "90s", "1d" → Sekunden
    static func duration(_ text: String) -> TimeInterval? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        let units: [(String, Double)] = [("d", 86400), ("h", 3600), ("m", 60), ("s", 1)]
        for (suffix, factor) in units where t.hasSuffix(suffix) {
            guard let v = Double(t.dropLast()) else { return nil }
            return v * factor
        }
        return Double(t).map { $0 * 60 }   // ohne Einheit: Minuten
    }

    /// "1h", "today", "24h", "7d" → Startzeitpunkt
    static func since(_ text: String) -> Date? {
        let t = text.lowercased()
        if t == "today" || t == "heute" { return Calendar.current.startOfDay(for: Date()) }
        if t == "all" || t == "alles" { return Date(timeIntervalSince1970: 0) }
        return duration(t).map { Date().addingTimeInterval(-$0) }
    }

    static func date(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd", "dd.MM.yyyy"] {
            f.dateFormat = format
            if let d = f.date(from: text) { return d }
        }
        return nil
    }

    static func tier(_ text: String) -> PolicyTier? {
        switch text.lowercased() {
        case "off", "aus", "0":                    return .off
        case "frugal", "sparsam", "1":             return .frugal
        case "vacation", "urlaub", "urlaubsmodus", "2": return .vacation
        case "emergency", "notfall", "3":          return .emergency
        default: return nil
        }
    }

    static func networkClass(_ text: String) -> NetworkClass? {
        switch text.lowercased() {
        case "free", "frei":         return .free
        case "metered", "teuer":     return .metered
        case "limited", "begrenzt":  return .limited
        case "unknown", "unbekannt": return .unknown
        default: return nil
        }
    }
}
