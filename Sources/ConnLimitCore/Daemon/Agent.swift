import Foundation

/// Der Hintergrunddienst: misst, bewertet, setzt durch.
///
/// Taktung:
///   alle 2 s   Sampling
///   alle 10 s  Netzwechsel prüfen
///   alle 30 s  Timer abarbeiten, Profil abgleichen
///   alle 60 s  Budget prüfen
///   stündlich  verdichten
public final class Agent {
    public struct Config: Sendable {
        public var sampleInterval: TimeInterval = 2
        public var networkInterval: TimeInterval = 10
        public var timerInterval: TimeInterval = 30
        public var budgetInterval: TimeInterval = 60
        /// Abgleich von Profil und tatsächlichen Sperren. Fängt auch Dienste
        /// ein, die erst nach dem Netzwechsel gestartet wurden.
        public var policyInterval: TimeInterval = 30
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

    // MARK: - Takt

    /// Was ein Takt bewirkt hat — für das Protokoll des Hintergrunddienstes
    /// und für die Oberfläche, die daraus ihre Hinweise bildet.
    public struct TickReport {
        public var networkChanged = false
        public var network: NetworkIdentity = .offline
        public var networkClass: NetworkClass = .unknown
        public var policy: PolicyEngine.SyncReport?
        public var closedGrants: [(service: String, bytes: Int64)] = []
        public var liftedTimers: [String] = []
        public var escalation: BudgetTracker.Escalation?
        /// Fehler einzelner Schritte. Ein Schritt, der scheitert, hält die
        /// übrigen nicht auf: Fällt etwa das Budget aus, sollen befristete
        /// Sperren trotzdem pünktlich ablaufen.
        public var errors: [Error] = []
    }

    private var lastNetworkCheck = Date.distantPast
    private var lastTimerCheck = Date.distantPast
    private var lastBudgetCheck = Date.distantPast
    private var lastPolicyCheck = Date.distantPast
    private var lastCompaction = Date.distantPast

    /// Einmal vor dem ersten Takt: Netz bestimmen und aufräumen, was ein
    /// abgestürzter Lauf hinterlassen hat. Liefert die freigegebenen Sperren.
    @discardableResult
    public func start() throws -> [String] {
        try refreshNetwork()
        lastNetworkCheck = Date()
        return try coordinator.recover(
            context: context,
            activeTier: policy.effectiveTier(networkClass: currentClass))
    }

    /// Ein Takt: messen, und was sonst gerade fällig ist.
    ///
    /// Eine Implementierung für den Hintergrunddienst und die App. Vorher
    /// lief der Zeitplan nur in `run()` — die App hat gemessen, aber beim
    /// Wechsel an den Hotspot kein Profil angewandt, befristete Sperren nie
    /// aufgehoben und die Rohdaten nie verdichtet.
    @discardableResult
    public func tick(now: Date = Date()) -> TickReport {
        var report = TickReport()
        func step(_ body: () throws -> Void) {
            do { try body() } catch { report.errors.append(error) }
        }

        var policyDue = false

        if now.timeIntervalSince(lastNetworkCheck) >= config.networkInterval {
            lastNetworkCheck = now
            step {
                let (_, _, changed) = try refreshNetwork()
                report.networkChanged = changed
                // Neues Netz ⇒ sofort neu bewerten, nicht erst im nächsten
                // Policy-Fenster: Am Hotspot zählt jede halbe Minute.
                if changed { policyDue = true }
            }
        }

        step { try tickSampling() }

        if now.timeIntervalSince(lastTimerCheck) >= config.timerInterval {
            lastTimerCheck = now
            step {
                report.closedGrants = try policy.expireGrants()
                report.liftedTimers = try policy.expireTimers()
                // Eine abgelaufene Freigabe heißt: zurück ins Profil.
                if !report.closedGrants.isEmpty { policyDue = true }
            }
        }

        if now.timeIntervalSince(lastBudgetCheck) >= config.budgetInterval {
            lastBudgetCheck = now
            step {
                report.escalation = try tickBudget()
                if report.escalation != nil { policyDue = true }
            }
        }

        if policyDue || now.timeIntervalSince(lastPolicyCheck) >= config.policyInterval {
            lastPolicyCheck = now
            step { report.policy = try tickPolicy() }
        }

        if now.timeIntervalSince(lastCompaction) >= config.compactInterval {
            lastCompaction = now
            step { try store.compact(now: now) }
        }

        report.network = currentNetwork
        report.networkClass = currentClass
        return report
    }

    public func runOnce() throws {
        try refreshNetwork()
        try tickSampling()
    }

    public func stop() { stopping = true }

    /// Blockierende Schleife. Bricht bei SIGINT/SIGTERM sauber ab und gibt
    /// dabei alle Profil-Sperren frei.
    public func run() throws {
        let released = try start()
        if config.verbose && !released.isEmpty {
            log(L("Wiederherstellung: freigegeben — %@", released.joined(separator: ", ")))
        }

        while !stopping {
            let report = tick()

            if report.networkChanged {
                log(L("Netzwechsel: %@ [%@]", report.network.displayLabel,
                      report.networkClass.displayName))
            }
            for closed in report.closedGrants {
                log(L("Freigabe beendet: %@ hat %@ verbraucht", closed.service,
                      ByteFormat.short(closed.bytes)))
            }
            for lifted in report.liftedTimers {
                log(L("Sperre abgelaufen: %@", lifted))
            }
            if let escalation = report.escalation {
                log(L("Automatik: Stufe %@ — %@", escalation.newTier.displayName, escalation.reason))
            }
            if let policy = report.policy, report.networkChanged || config.verbose {
                logReport(policy)
            }
            for error in report.errors {
                log(L("Fehler im Takt: %@", error.localizedDescription))
            }

            Thread.sleep(forTimeInterval: config.sampleInterval)
        }

        log(L("Beende — gebe Profil-Sperren frei"))
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
        if !report.blocked.isEmpty { log(L("Gesperrt: %@", report.blocked.joined(separator: ", "))) }
        if !report.released.isEmpty { log(L("Freigegeben: %@", report.released.joined(separator: ", "))) }
        for f in report.failed { log(L("Fehlgeschlagen: %@ — %@", f.service, f.reason)) }
    }
}
