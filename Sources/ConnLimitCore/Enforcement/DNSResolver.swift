import Foundation

/// Löst Domains zu IP-Adressen auf — die Grundlage für PF-Regeln.
public enum DNSResolver {

    public static func addresses(for domains: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for domain in domains {
            for address in resolve(domain) where !seen.contains(address) {
                seen.insert(address)
                result.append(address)
            }
        }
        return result
    }

    public static func resolve(_ host: String) -> [String] {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM,
                             ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil,
                             ai_addr: nil, ai_next: nil)
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &info) == 0, let head = info else { return [] }
        defer { freeaddrinfo(head) }

        var out: [String] = []
        var node: UnsafeMutablePointer<addrinfo>? = head
        while let current = node {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(current.pointee.ai_addr, current.pointee.ai_addrlen,
                           &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                let address = String(cString: buffer)
                // Link-lokale IPv6-Adressen tragen einen Zonenindex ("%en0"),
                // den PF nicht annimmt.
                if !address.contains("%") { out.append(address) }
            }
            node = current.pointee.ai_next
        }
        return out
    }
}
