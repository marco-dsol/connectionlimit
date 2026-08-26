import Foundation

/// Ein Hebel, mit dem ein Dienst gestoppt werden kann.
/// Reihenfolge in `Service.levers` = Präferenz.
public enum LeverSpec: Codable, Sendable, Equatable {
    /// `launchctl kill SIGSTOP system/<job>` — sauber und vollständig reversibel.
    case launchdFreeze(jobs: [String])
    /// `kill -STOP <pid>` — friert die ganze App ein, nicht nur ihr Netz.
    case processFreeze
    /// PF-Anchor mit aufgelösten Ziel-IPs. Grob: CDN-Adressen veralten.
    case pfDomains(domains: [String])
    /// App-eigenes Pause-Kommando (freundlichster Hebel, wo vorhanden).
    case appPause(command: [String], resume: [String])

    public var kind: LeverKind {
        switch self {
        case .launchdFreeze: return .launchdFreeze
        case .processFreeze: return .processFreeze
        case .pfDomains:     return .pfDomains
        case .appPause:      return .appPause
        }
    }

    private enum CodingKeys: String, CodingKey { case type, jobs, domains, command, resume }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "launchdFreeze":
            self = .launchdFreeze(jobs: try c.decode([String].self, forKey: .jobs))
        case "processFreeze":
            self = .processFreeze
        case "pfDomains":
            self = .pfDomains(domains: try c.decode([String].self, forKey: .domains))
        case "appPause":
            self = .appPause(command: try c.decode([String].self, forKey: .command),
                             resume: try c.decode([String].self, forKey: .resume))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c,
                debugDescription: "Unbekannter Hebel-Typ: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind.rawValue, forKey: .type)
        switch self {
        case .launchdFreeze(let jobs):    try c.encode(jobs, forKey: .jobs)
        case .processFreeze:              break
        case .pfDomains(let domains):     try c.encode(domains, forKey: .domains)
        case .appPause(let cmd, let res): try c.encode(cmd, forKey: .command)
                                          try c.encode(res, forKey: .resume)
        }
    }
}

public enum LeverKind: String, Codable, Sendable {
    case launchdFreeze, processFreeze, pfDomains, appPause, neFilter

    /// Braucht dieser Hebel root?
    public var needsRoot: Bool {
        switch self {
        case .launchdFreeze, .pfDomains: return true
        case .processFreeze, .appPause, .neFilter: return false
        }
    }

    /// Wie grob wirkt der Hebel? Wird in der UI als Warnhinweis gezeigt.
    public var bluntnessNote: String? {
        switch self {
        case .processFreeze: return "friert die App komplett ein, nicht nur ihr Netz"
        case .pfDomains:     return "sperrt bekannte Ziel-Adressen; CDN-Adressen können ausweichen"
        case .launchdFreeze, .appPause, .neFilter: return nil
        }
    }
}

/// Wie ein Dienst in den Messdaten wiedererkannt wird.
public struct ServiceMatch: Codable, Sendable {
    public var processes: [String]
    public var bundleIds: [String]
    public var pathPrefixes: [String]

    public init(processes: [String] = [], bundleIds: [String] = [], pathPrefixes: [String] = []) {
        self.processes = processes
        self.bundleIds = bundleIds
        self.pathPrefixes = pathPrefixes
    }
}

public struct Service: Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var serviceClass: ServiceClass
    public var match: ServiceMatch
    public var levers: [LeverSpec]
    public var note: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, match, levers, note
        case serviceClass = "class"
    }

    public init(id: String, name: String, serviceClass: ServiceClass,
                match: ServiceMatch, levers: [LeverSpec] = [], note: String? = nil) {
        self.id = id
        self.name = name
        self.serviceClass = serviceClass
        self.match = match
        self.levers = levers
        self.note = note
    }

    public var isBlockable: Bool { serviceClass.isBlockable && !levers.isEmpty }

    /// Dienst für einen Prozess, den der Katalog nicht kennt. Erscheint mit
    /// Verbrauch in der Liste, damit der Nutzer ihn einordnen kann.
    public static func unknown(processName: String) -> Service {
        Service(id: "unknown:\(processName)",
                name: processName,
                serviceClass: .other,
                match: ServiceMatch(processes: [processName]),
                levers: [.processFreeze])
    }

    public var isUnknown: Bool { id.hasPrefix("unknown:") }
}
