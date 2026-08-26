import Foundation

/// Sperrt Ziel-Adressen über einen eigenen PF-Anchor.
///
/// **Grenzen, die die UI benennen muss:** PF kennt keine Prozesse. Gesperrt
/// werden aufgelöste IP-Adressen der bekannten Domains eines Dienstes. Dienste
/// hinter großen CDNs (Fastly, Cloudflare) können auf andere Adressen
/// ausweichen. Für Cloud-Anbieter mit stabilen Endpunkten reicht es gut.
///
/// Der Vorteil gegenüber dem Einfrieren: die App bleibt bedienbar, und die
/// Regel lässt sich an ein Interface binden — sie greift also nur im teuren
/// Netz und nicht im Heim-WLAN.
public final class PFEnforcer: Enforcer {
    public let kind: LeverKind = .pfDomains
    public static let anchorRoot = "at.mitsol.connectionlimit"
    private let pfctl = "/sbin/pfctl"

    public init() {}

    public func canEnforce(_ service: Service, spec: LeverSpec, context: EnforcementContext) -> Bool {
        guard case .pfDomains(let domains) = spec, !domains.isEmpty else { return false }
        return Shell.isRoot && PFAnchor.isInstalled && !context.network.isOffline
    }

    public func apply(_ service: Service, spec: LeverSpec, receipt: inout EnforcementReceipt,
                      context: EnforcementContext) throws {
        guard case .pfDomains(let domains) = spec else {
            throw EnforcementError.leverFailed(.pfDomains, "falscher Hebel-Typ")
        }
        guard Shell.isRoot else { throw EnforcementError.needsRoot(.pfDomains) }
        guard PFAnchor.isInstalled else { throw EnforcementError.pfAnchorMissing }

        let addresses = DNSResolver.addresses(for: domains)
        guard !addresses.isEmpty else {
            throw EnforcementError.leverFailed(.pfDomains,
                "keine der Domains ließ sich auflösen — ohne Adressen gibt es nichts zu sperren")
        }

        let anchor = "\(Self.anchorRoot)/\(sanitize(service.id))"
        let table = "cl_\(sanitize(service.id))"
        let iface = context.network.interface

        let ruleset = """
        table <\(table)> persist { \(addresses.joined(separator: ", ")) }
        block drop out quick on \(iface) from any to <\(table)>
        block drop in quick on \(iface) from <\(table)> to any
        """

        try PFAnchor.load(anchor: anchor, ruleset: ruleset)
        receipt.payload.anchorRule = anchor
    }

    public func revert(_ receipt: EnforcementReceipt) throws {
        guard let anchor = receipt.payload.anchorRule else { return }
        guard Shell.isRoot else { throw EnforcementError.needsRoot(.pfDomains) }
        try PFAnchor.flush(anchor: anchor)
    }

    /// PF-Anchor-Namen dürfen keine Sonderzeichen enthalten.
    private func sanitize(_ id: String) -> String {
        String(id.map { $0.isLetter || $0.isNumber ? $0 : "_" })
    }
}

/// Verwaltet den PF-Anchor: Installation in /etc/pf.conf, Laden, Leeren.
public enum PFAnchor {
    static let pfctl = "/sbin/pfctl"
    static let pfConf = "/etc/pf.conf"
    public static let anchorLine = "anchor \"\(PFEnforcer.anchorRoot)/*\""

    /// Ist der Anchor in /etc/pf.conf referenziert? PF wertet nur Anchors aus,
    /// die im geladenen Regelsatz vorkommen — ohne diesen Eintrag wären unsere
    /// Regeln wirkungslos, ohne dass irgendetwas fehlschlägt.
    public static var isInstalled: Bool {
        guard let conf = try? String(contentsOfFile: pfConf, encoding: .utf8) else { return false }
        return conf.contains(PFEnforcer.anchorRoot)
    }

    /// Einmalige Installation. Legt eine Sicherung von /etc/pf.conf an.
    public static func install() throws {
        guard Shell.isRoot else { throw EnforcementError.needsRoot(.pfDomains) }
        guard !isInstalled else { return }

        let conf = try String(contentsOfFile: pfConf, encoding: .utf8)
        let backup = pfConf + ".connlimit-backup"
        if !FileManager.default.fileExists(atPath: backup) {
            try conf.write(toFile: backup, atomically: true, encoding: .utf8)
        }
        let updated = conf.hasSuffix("\n") ? conf + anchorLine + "\n" : conf + "\n" + anchorLine + "\n"
        try updated.write(toFile: pfConf, atomically: true, encoding: .utf8)

        _ = try Shell.check(pfctl, ["-f", pfConf])
        _ = try? Shell.run(pfctl, ["-e"])      // bereits aktiv ⇒ Status 1, egal
    }

    public static func uninstall() throws {
        guard Shell.isRoot else { throw EnforcementError.needsRoot(.pfDomains) }
        try flushAll()
        guard let conf = try? String(contentsOfFile: pfConf, encoding: .utf8) else { return }
        let cleaned = conf.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.contains(PFEnforcer.anchorRoot) }
            .joined(separator: "\n")
        try cleaned.write(toFile: pfConf, atomically: true, encoding: .utf8)
        _ = try? Shell.run(pfctl, ["-f", pfConf])
    }

    static func load(anchor: String, ruleset: String) throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("connlimit-\(UUID().uuidString).pf")
        try ruleset.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let r = try Shell.run(pfctl, ["-a", anchor, "-f", tmp.path])
        guard r.ok else {
            throw EnforcementError.leverFailed(.pfDomains, r.stderr.isEmpty ? r.stdout : r.stderr)
        }
    }

    public static func flush(anchor: String) throws {
        _ = try? Shell.run(pfctl, ["-a", anchor, "-F", "all"])
    }

    /// Räumt **alle** Regeln dieses Werkzeugs weg. Das ist der Not-Aus und
    /// zugleich das, was der Boot-Wächter aufruft.
    public static func flushAll() throws {
        guard Shell.isRoot else { throw EnforcementError.needsRoot(.pfDomains) }
        let list = (try? Shell.run(pfctl, ["-a", PFEnforcer.anchorRoot, "-s", "Anchors"]))?.stdout ?? ""
        for line in list.split(separator: "\n") {
            let name = line.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            try flush(anchor: name)
        }
        try flush(anchor: PFEnforcer.anchorRoot)
    }
}
