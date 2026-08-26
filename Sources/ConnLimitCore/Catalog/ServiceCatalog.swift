import Foundation

/// Übersetzt Prozesse in benannte Dienste.
///
/// Matching-Reihenfolge (genauester Treffer zuerst):
///  1. Bundle-ID
///  2. Pfad-Präfix
///  3. Prozessname exakt
///  4. Prozessname als Präfix — Fallback für nettops 15-Zeichen-Kürzung
///  5. kein Treffer ⇒ `unknown:<name>`
public final class ServiceCatalog {
    public private(set) var services: [Service]

    private var byBundleId: [String: Service] = [:]
    private var byProcessName: [String: Service] = [:]
    private var pathPrefixes: [(prefix: String, service: Service)] = []
    private var truncationCandidates: [(name: String, service: Service)] = []

    private var resolutionCache: [String: Service] = [:]

    public init(services: [Service]) {
        self.services = services
        reindex()
    }

    public static func builtin() -> ServiceCatalog {
        ServiceCatalog(services: BuiltinCatalog.services)
    }

    /// Baut den Katalog aus den mitgelieferten Diensten plus einer optionalen
    /// Nutzerdatei. Gleiche `id` ⇒ die Nutzerdefinition gewinnt.
    public static func load(userFile: URL?) -> ServiceCatalog {
        var merged = BuiltinCatalog.services
        if let userFile, let data = try? Data(contentsOf: userFile) {
            do {
                let custom = try JSONDecoder().decode([Service].self, from: data)
                var index = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
                for s in custom { index[s.id] = s }
                merged = Array(index.values)
            } catch {
                FileHandle.standardError.write(
                    "connlimit: Katalogdatei \(userFile.path) ignoriert — \(error)\n"
                        .data(using: .utf8)!)
            }
        }
        return ServiceCatalog(services: merged.sorted { $0.id < $1.id })
    }

    private func reindex() {
        byBundleId.removeAll(); byProcessName.removeAll()
        pathPrefixes.removeAll(); truncationCandidates.removeAll()
        resolutionCache.removeAll()

        for service in services {
            for b in service.match.bundleIds { byBundleId[b.lowercased()] = service }
            for p in service.match.pathPrefixes { pathPrefixes.append((p, service)) }
            for n in service.match.processes {
                byProcessName[n.lowercased()] = service
                if n.count > NettopNameLimit {
                    truncationCandidates.append((n.lowercased(), service))
                }
            }
        }
        // Längste Pfad-Präfixe zuerst, damit spezifischere Regeln gewinnen.
        pathPrefixes.sort { $0.prefix.count > $1.prefix.count }
    }

    /// nettop kürzt Prozessnamen auf 15 Zeichen.
    private let NettopNameLimit = 15

    public func service(id: String) -> Service? {
        services.first { $0.id == id }
    }

    /// Wie `service(id:)`, fällt aber auf einen Platzhalter zurück statt auf
    /// nil. Messdaten enthalten Dienste, die der Katalog nicht kennt — die
    /// sollen mit ihrem Prozessnamen in der Liste stehen, nicht verschwinden.
    public func serviceOrUnknown(id: String) -> Service {
        service(id: id)
            ?? .unknown(processName: id.replacingOccurrences(of: "unknown:", with: ""))
    }

    public func resolve(processName: String, info: ProcessResolver.Info?) -> Service {
        let cacheKey = "\(processName)|\(info?.executablePath ?? "")"
        if let hit = resolutionCache[cacheKey] { return hit }
        let result = computeResolve(processName: processName, info: info)
        resolutionCache[cacheKey] = result
        return result
    }

    private func computeResolve(processName: String, info: ProcessResolver.Info?) -> Service {
        if let bundleId = info?.bundleId?.lowercased(), let hit = byBundleId[bundleId] {
            return hit
        }
        if let path = info?.executablePath {
            for entry in pathPrefixes where path.hasPrefix(entry.prefix) {
                return entry.service
            }
            // Basename des echten Pfads — verlässlicher als der gekürzte
            // nettop-Name, wenn kein Bundle vorhanden ist (reine Daemons).
            let base = (path as NSString).lastPathComponent.lowercased()
            if let hit = byProcessName[base] { return hit }
        }

        let lower = processName.lowercased()
        if let hit = byProcessName[lower] { return hit }

        // Gekürzter Name: Katalogeintrag, der mit dem gekürzten Namen beginnt.
        if processName.count >= NettopNameLimit {
            for candidate in truncationCandidates where candidate.name.hasPrefix(lower) {
                return candidate.service
            }
        }

        return .unknown(processName: processName)
    }

    public func services(inClass cls: ServiceClass) -> [Service] {
        services.filter { $0.serviceClass == cls }
    }
}
