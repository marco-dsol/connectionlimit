import Foundation

/// Der Hintergrunddienst: misst, bewertet, setzt durch.
///
/// Taktung (siehe `.knowledgebase/03-architektur.md`):
///   alle 2 s   Sampling
///   alle 10 s  Netzwechsel prüfen
///   alle 30 s  Timer abarbeiten
///   alle 60 s  Budget prüfen
///   stündlich  verdichten
public final class Agent {
    public struct Config: Sendable {
        public var sampleInterval: TimeInterval = 2
        public var networkInterval: TimeInterval = 10
        public var timerInterval: TimeInterval = 30
        public var budgetInterval: TimeInterval = 60
        public var compactInterval: TimeInterval = 3600
        /// Nur messen, nichts sperren — für den ersten Einsatz sinnvoll.
        public var readOnly: Bool = false
        public var verbose: Bool = false

        public init() {}
    }

    public let store: Store
    public let catalog: ServiceCatalog
    public let coordinator: EnforcementCoordinator
    public let policy: PolicyEngine
    public let budget: BudgetTracker

    private let identifier = NetworkIdentifier()
    private let resolver = ProcessResolver()
    private let accumulator = DeltaAccumulator()
    private var sampler = NettopSampler()
    private var config: Config

    private var currentNetwork: NetworkIdentity = .offline
    private var currentClass: NetworkClass = .unknown
    private var lastPIDsByService: [String: [Int32]] = [:]
    private var lastRates: [String: Double] = [:]

    private var stopping = false

    public init(store: Store, catalog: ServiceCatalog, config: Config = Config()) {
        self.store = store
        self.catalog = catalog
        self.config = config
        self.coordinator = EnforcementCoordinator(store: store, catalog: catalog)
        self.policy = PolicyEngine(store: store, catalog: catalog, coordinator: coordinator)
        self.budget = BudgetTracker(store: store)
    }

    // MARK: - Netz

    @discardableResult
    public func refreshNetwork() throws -> (identity: NetworkIdentity, class: NetworkClass, changed: Bool) {
        let identity = identifier.current()
        let changed = identity.id != currentNetwork.id

        var cls = try store.networkClass(for: identity.id) ?? .unknown
        if changed || cls == .unknown {
            if try store.networkClass(for: identity.id) == nil {
                cls = identifier.suggestedClass(for: identity)
                try store.upsertNetwork(identity, class: cls)
            } else {
                try store.upsertNetwork(identity, class: cls)
            }
        } else {
            try store.upsertNetwork(identity, class: cls)
        }

        currentNetwork = identity
        currentClass = cls
        // Immer typgefiltert sampeln, sonst zählt VPN-Traffic doppelt.
        sampler.linkType = identity.linkType
        if changed { accumulator.reset() }
        return (identity, cls, changed)
    }

    public var network: (identity: NetworkIdentity, class: NetworkClass) {
        (currentNetwork, currentClass)
    }

    public var context: EnforcementContext {
        EnforcementContext(network: currentNetwork, livePIDs: lastPIDsByService)
    }

    // MARK: - Messen

    /// Ein Messtakt. Liefert die Zuwächse, die verbucht wurden.
    @discardableResult
    public func tickSampling() throws -> [UsageDelta] {
        let samples = try sampler.sample()
        let result = accumulator.ingest(samples)
        resolver.prune(livePIDs: result.livePIDs)

        // PID-Zuordnung für alle laufenden Prozesse pflegen, nicht nur für die
        // mit Zuwachs — sonst findet der Enforcer stille Sync-Clients nicht.
        var pidsByService: [String: [Int32]] = [:]
        for s in samples {
            let service = catalog.resolve(processName: s.name, info: resolver.info(for: s.pid))
            pidsByService[service.id, default: []].append(s.pid)
        }
        lastPIDsByService = pidsByService

        var totals: [String: (Int64, Int64)] = [:]
        for d in result.deltas {
            let service = catalog.resolve(processName: d.name, info: resolver.info(for: d.pid))
            totals[service.id, default: (0, 0)].0 += d.bytesIn
            totals[service.id, default: (0, 0)].1 += d.bytesOut
        }

        let deltas = totals.map { UsageDelta(serviceId: $0.key, bytesIn: $0.value.0, bytesOut: $0.value.1) }
        if result.interval > 0 {
            lastRates = deltas.reduce(into: [:]) { $0[$1.serviceId] = Double($1.total) / result.interval }
        }

        let now = Date()
        try store.record(deltas: deltas, at: now,
                         network: currentNetwork, networkClass: currentClass)

        // Verkehr trotz gesetzter Sperre protokollieren. Ob dahinter ein echter
        // Verbindungsversuch steckt, lässt sich ohne Netzwerkfilter nicht
        // sagen — messbar ist, dass Bytes gezählt wurden, während die Sperre
        // stand. Genau das wird festgehalten, mit Zeitpunkt und Menge.
        let blocked = (try? store.blockedServiceIds()) ?? []
        if !blocked.isEmpty {
            for d in deltas where blocked.contains(d.serviceId) && d.total > 0 {
                try? store.recordAttempt(serviceId: d.serviceId, bytes: d.total, at: now)
            }
        }
        return deltas
    }

    public var rates: [String: Double] { lastRates }

    // MARK: - Durchsetzen

    @discardableResult
    public func tickPolicy() throws -> PolicyEngine.SyncReport? {
        guard !config.readOnly else { return nil }
        return try policy.apply(networkClass: currentClass, context: context)
    }

    @discardableResult
    public func tickBudget() throws -> BudgetTracker.Escalation? {
        guard !config.readOnly else { return nil }
        let tier = policy.effectiveTier(networkClass: currentClass)
        guard let escalation = try budget.escalation(from: tier) else { return nil }
        var state = store.policyState
        state.manualTier = escalation.newTier
        try store.savePolicyState(state)
        return escalation
    }

    // MARK: - Lauf

    public func runOnce() throws {
        try refreshNetwork()
        try tickSampling()
    }

    public func stop() { stopping = true }

    /// Blockierende Schleife. Bricht bei SIGINT/SIGTERM sauber ab und gibt
    /// dabei alle Profil-Sperren frei.
    public func run() throws {
        try refreshNetwork()
        let released = try coordinator.recover(
            context: context,
            activeTier: policy.effectiveTier(networkClass: currentClass))
        if config.verbose && !released.isEmpty {
            log("Wiederherstellung: freigegeben — \(released.joined(separator: ", "))")
        }

        var lastNetwork = Date.distantPast
        var lastTimer = Date.distantPast
        var lastBudget = Date.distantPast
        var lastCompact = Date.distantPast
        var lastPolicy = Date.distantPast

        while !stopping {
            let now = Date()
            do {
                if now.timeIntervalSince(lastNetwork) >= config.networkInterval {
                    lastNetwork = now
                    let (identity, cls, changed) = try refreshNetwork()
                    if changed {
                        log("Netzwechsel: \(identity.label) [\(cls.displayName)]")
                        if let report = try tickPolicy() { logReport(report) }
                        lastPolicy = now
                    }
                }

                try tickSampling()

                if now.timeIntervalSince(lastTimer) >= config.timerInterval {
                    lastTimer = now
                    for closed in try policy.expireGrants() {
                        log("Freigabe beendet: \(closed.service) hat \(ByteFormat.short(closed.bytes)) verbraucht")
                    }
                    for lifted in try policy.expireTimers() {
                        log("Sperre abgelaufen: \(lifted)")
                    }
                }

                if now.timeIntervalSince(lastBudget) >= config.budgetInterval {
                    lastBudget = now
                    if let escalation = try tickBudget() {
                        log("Automatik: Stufe \(escalation.newTier.displayName) — \(escalation.reason)")
                    }
                }

                if now.timeIntervalSince(lastPolicy) >= 30 {
                    lastPolicy = now
                    if let report = try tickPolicy(), config.verbose { logReport(report) }
                }

                if now.timeIntervalSince(lastCompact) >= config.compactInterval {
                    lastCompact = now
                    try store.compact()
                }
            } catch {
                log("Fehler im Takt: \(error.localizedDescription)")
            }

            Thread.sleep(forTimeInterval: config.sampleInterval)
        }

        log("Beende — gebe Profil-Sperren frei")
        try? releaseProfileBlocks()
    }

    /// Beim Beenden werden Profil-Sperren aufgehoben. Manuelle Sperren bleiben
    /// bestehen — die hat der Nutzer bewusst gesetzt.
    public func releaseProfileBlocks() throws {
        for receipt in try store.openReceipts() where receipt.reason == .profile {
            try? coordinator.revert(receipt)
        }
    }

    private func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write("[\(stamp)] \(message)\n".data(using: .utf8)!)
    }

    private func logReport(_ report: PolicyEngine.SyncReport) {
        if !report.blocked.isEmpty { log("Gesperrt: \(report.blocked.joined(separator: ", "))") }
        if !report.released.isEmpty { log("Freigegeben: \(report.released.joined(separator: ", "))") }
        for f in report.failed { log("Fehlgeschlagen: \(f.service) — \(f.reason)") }
    }
}
