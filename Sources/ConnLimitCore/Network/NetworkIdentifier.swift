import Foundation
import CryptoKit

/// Erkennt, in welchem Netz der Mac gerade hängt.
///
/// **Warum Gateway-MAC statt SSID:** Seit macOS 14 verlangt das Auslesen der
/// SSID die Berechtigung „Ortungsdienste". Für ein Werkzeug, das keine Position
/// braucht, ist das eine unangemessene Hürde. Die MAC-Adresse des Default-
/// Gateways ist ohne jede Berechtigung lesbar und pro Netz stabil — ein
/// iPhone-Hotspot hat immer dieselbe.
public struct NetworkIdentifier {

    public init() {}

    public func current() -> NetworkIdentity {
        guard let route = defaultRoute() else { return .offline }
        let mac = gatewayMAC(for: route.gateway, interface: route.interface)
        let linkType = self.linkType(for: route.interface)

        // Ohne MAC (z. B. Point-to-Point-Link) fällt die Identität auf
        // Interface + Gateway-IP zurück. Weniger stabil, aber besser als nichts.
        let seed = "\(linkType.rawValue)|\(mac ?? route.gateway)|\(route.interface)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        let id = digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16)

        return NetworkIdentity(
            id: String(id),
            interface: route.interface,
            linkType: linkType,
            gatewayIP: route.gateway,
            gatewayMAC: mac,
            label: Self.defaultLabel(gateway: route.gateway, linkType: linkType,
                                     interface: route.interface, localized: false)
        )
    }

    /// Einstufung für ein noch unbekanntes Netz.
    ///
    /// Nur dort raten, wo die Heuristik sicher ist. Ein unbekanntes WLAN bleibt
    /// `unknown` — die App fragt lieber einmal nach, als still das Falsche zu tun.
    public func suggestedClass(for identity: NetworkIdentity) -> NetworkClass {
        if identity.isOffline { return .unknown }
        if isIOSHotspot(gateway: identity.gatewayIP) { return .metered }
        if identity.linkType == .wired { return .free }
        return .unknown
    }

    /// iOS Personal Hotspot vergibt reproduzierbar 172.20.10.1/28.
    public func isIOSHotspot(gateway: String) -> Bool {
        gateway == "172.20.10.1"
    }

    // MARK: - Ermittlung

    struct DefaultRoute { var gateway: String; var interface: String }

    func defaultRoute() -> DefaultRoute? {
        guard let out = try? Shell.run("/sbin/route", ["-n", "get", "default"]), out.ok else {
            return nil
        }
        var gateway: String?, interface: String?
        for line in out.stdout.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else { continue }
            if parts[0] == "gateway" { gateway = parts[1] }
            if parts[0] == "interface" { interface = parts[1] }
        }
        guard let interface else { return nil }
        // Kein Gateway = direkt verbundenes Netz; Interface allein muss reichen.
        return DefaultRoute(gateway: gateway ?? "-", interface: interface)
    }

    func gatewayMAC(for ip: String, interface: String) -> String? {
        guard ip != "-" else { return nil }
        guard let out = try? Shell.run("/usr/sbin/arp", ["-n", ip]), out.ok else { return nil }
        // "? (192.168.9.1) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]"
        guard let atRange = out.stdout.range(of: " at ") else { return nil }
        let rest = out.stdout[atRange.upperBound...]
        guard let mac = rest.split(separator: " ").first else { return nil }
        let value = String(mac)
        return value.contains(":") && value != "(incomplete)" ? value : nil
    }

    /// Wi-Fi oder Kabel? Über `networksetup -listallhardwareports`, das ohne
    /// Sonderrechte auskommt.
    func linkType(for interface: String) -> LinkType {
        guard let out = try? Shell.run("/usr/sbin/networksetup", ["-listallhardwareports"]),
              out.ok else { return .other }

        var currentPort: String?
        for line in out.stdout.split(separator: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("Hardware Port:") {
                currentPort = String(l.dropFirst("Hardware Port:".count)).trimmingCharacters(in: .whitespaces)
            } else if l.hasPrefix("Device:") {
                let device = String(l.dropFirst("Device:".count)).trimmingCharacters(in: .whitespaces)
                if device == interface {
                    let port = (currentPort ?? "").lowercased()
                    if port.contains("wi-fi") || port.contains("airport") { return .wifi }
                    if port.contains("ethernet") || port.contains("lan") || port.contains("thunderbolt") {
                        return .wired
                    }
                    return .other
                }
            }
        }
        return .other
    }

    /// Automatischer Name eines Netzes.
    ///
    /// In der Datenbank steht immer die deutsche Fassung (`localized: false`);
    /// `NetworkIdentity.displayLabel` erkennt sie daran wieder und zeigt sie in
    /// der geltenden Sprache.
    static func defaultLabel(gateway: String, linkType: LinkType, interface: String,
                             localized: Bool) -> String {
        let t: (String) -> String = localized ? { L($0) } : { $0 }
        if gateway == "172.20.10.1" { return t("iPhone-Hotspot") }
        switch linkType {
        case .wifi:  return t("WLAN") + " (\(gateway))"
        case .wired: return t("Kabel") + " (\(interface))"
        case .other: return t("Netz") + " (\(interface))"
        }
    }
}
