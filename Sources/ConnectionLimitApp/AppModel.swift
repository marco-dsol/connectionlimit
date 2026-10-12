import Foundation
import SwiftUI
import Combine
import ConnLimitCore

/// Bindeglied zwischen Kern und Oberfläche.
///
/// Das Sampling läuft auf einer eigenen Warteschlange — `nettop` braucht pro
/// Aufruf ein paar hundert Millisekunden, und die dürfen die Menüleiste nicht
/// blockieren.
@MainActor
final class AppModel: ObservableObject {

    @Published private(set) var network: NetworkIdentity = .offline
    @Published private(set) var networkClass: NetworkClass = .unknown
    @Published private(set) var tier: PolicyTier = .off
    @Published private(set) var policyState = PolicyState()
    /// Was gerade sendet — die Kurzliste für die Menüleiste.
    @Published private(set) var live: [ServiceUsage] = []
    /// Die Dauerliste: jeder Dienst, der je Daten gebraucht hat, bis zum Reset.
    @Published private(set) var tracked: [ServiceUsage] = []
    @Published private(set) var trackingSince: Date?
    @Published private(set) var history: [String: [HistoryBucket]] = [:]
    @Published private(set) var recentEvents: [ServiceEvent] = []
    @Published private(set) var blocked: [BlockedItem] = []
    @Published private(set) var grants: [GrantItem] = []
    @Published private(set) var budgetStatus: BudgetStatus?
    @Published private(set) var networks: [NetworkRecord] = []
    @Published var lastError: String?
    @Published private(set) var isEnforcing = false
    /// Dienste, die das Profil sperren würde, für die aber alle Hebel root
    /// brauchen. Muss sichtbar sein — sonst hält der Nutzer für gesperrt, was
    /// in Wahrheit weiterläuft.
    @Published private(set) var needsRoot: [String] = []
    /// Sprache der Oberfläche. Ändert sie sich, zeichnen Menü und Fenster
    /// vollständig neu — die Texte entstehen beim Zeichnen.
    @Published private(set) var language: Language = L10n.language
    @Published private(set) var languagePreference: LanguagePreference = L10n.storedPreference

    struct BlockedItem: Identifiable {
        let id: String
        let name: String
        let lever: LeverKind
        let reason: EnforcementReceipt.Reason
        let expiresAt: Date?
        let receiptId: String
    }

    struct GrantItem: Identifiable {
        let id: String
        let name: String
        let until: Date
        let spent: Int64
    }

    let store: Store
    let catalog: ServiceCatalog
    private let agent: Agent
    private let work = DispatchQueue(label: "at.mitsol.connectionlimit.ui-sampling")
    private var timer: Timer?
    /// Der Verlauf ändert sich in Stundenfenstern — ihn im 2-s-Takt neu zu
    /// laden wäre pure Last ohne sichtbaren Unterschied.
    private var historyLoadedAt = Date.distantPast

    init(storePath: String = Store.defaultPath) throws {
        store = try Store(path: storePath)
        catalog = ServiceCatalog.load(userFile: Store.catalogPath)
        var config = Agent.Config()
        config.sampleInterval = 2
        // Die App zeigt das Netz an — ein Wechsel soll nach Sekunden sichtbar
        // sein, nicht erst nach zehn.
        config.networkInterval = 4
        agent = Agent(store: store, catalog: catalog, config: config)
    }

    func start() {
        work.async { [agent] in
            // Aufräumen, was ein abgestürzter Lauf hinterlassen hat — vorher
            // geschah das nur im Hintergrunddienst, nie in der App.
            let recovered = Result { try agent.start() }
            let snapshot = Snapshot(agent)
            Task { @MainActor [weak self] in
                if case .failure(let error) = recovered { self?.lastError = error.localizedDescription }
                self?.historyLoadedAt = .distantPast
                self?.reloadFromStore(snapshot)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Takt

    /// Was die Oberfläche vom Agenten braucht, auf dessen Warteschlange
    /// abgegriffen. Direkt aus dem Hauptthread gelesen liefe das Lesen mit
    /// dem Schreiben des nächsten Messtakts um die Wette.
    private struct Snapshot {
        var network: NetworkIdentity
        var networkClass: NetworkClass
        var rates: [String: Double]

        init(_ agent: Agent) {
            (network, networkClass) = agent.network
            rates = agent.rates
        }
    }

    private var lastSnapshot: Snapshot?

    private func tick() {
        work.async { [agent] in
            // Derselbe Zeitplan wie im Hintergrunddienst: messen, Netzwechsel,
            // Timer, Budget, Profil-Abgleich, Verdichten.
            let report = agent.tick()
            let snapshot = Snapshot(agent)
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error = report.errors.first { self.lastError = error.localizedDescription }
                if let policy = report.policy { self.needsRoot = policy.needsRoot }
                if report.networkChanged { self.historyLoadedAt = .distantPast }
                // `connlimit lang en` im Terminal schaltet auch die laufende
                // App um — es ist dieselbe Einstellung.
                let stored = L10n.storedPreference
                if stored != self.languagePreference { self.setLanguage(stored) }
                self.reloadFromStore(snapshot)
            }
        }
    }

    func refreshNow() {
        work.async { [agent] in
            _ = try? agent.refreshNetwork()
            _ = try? agent.tickSampling()
            let snapshot = Snapshot(agent)
            Task { @MainActor [weak self] in
                self?.historyLoadedAt = .distantPast
                self?.reloadFromStore(snapshot)
            }
        }
    }

    private func reloadFromStore(_ fresh: Snapshot? = nil) {
        if let fresh { lastSnapshot = fresh }
        guard let snapshot = lastSnapshot else { return }
        let now = Date()
        network = snapshot.network
        networkClass = snapshot.networkClass
        let cls = snapshot.networkClass
        policyState = store.policyState
        tier = agent.policy.effectiveTier(networkClass: cls)

        let rates = snapshot.rates
        let blockedIds = (try? store.blockedServiceIds()) ?? []

        tracked = (try? store.trackedUsage(catalog: catalog, rates: rates, now: now)) ?? []
        trackingSince = (try? store.trackingSince()) ?? nil

        live = rates
            .filter { $0.value > 256 }
            .sorted { $0.value > $1.value }
            .prefix(12)
            .map { entry in
                ServiceUsage(service: catalog.serviceOrUnknown(id: entry.key),
                             bytesIn: 0, bytesOut: 0,
                             rate: entry.value, isBlocked: blockedIds.contains(entry.key),
                             lastSeen: now)
            }

        if now.timeIntervalSince(historyLoadedAt) > 30 {
            historyLoadedAt = now
            history = (try? store.history(serviceIds: tracked.map(\.id),
                                          since: now.addingTimeInterval(-24 * 3600),
                                          until: now, bucket: 3600)) ?? [:]
        }

        recentEvents = (try? store.events(since: now.addingTimeInterval(-14 * 86400), limit: 120)) ?? []

        blocked = ((try? store.openReceipts()) ?? []).map { r in
            BlockedItem(id: r.serviceId, name: catalog.serviceOrUnknown(id: r.serviceId).displayName,
                        lever: r.lever, reason: r.reason, expiresAt: r.expiresAt, receiptId: r.id)
        }.sorted { $0.name < $1.name }

        grants = ((try? store.grants()) ?? []).filter { !$0.isExpired }.map { g in
            let used = (try? store.serviceTotal(g.serviceId)) ?? 0
            return GrantItem(id: g.id, name: catalog.serviceOrUnknown(id: g.serviceId).displayName,
                             until: g.until, spent: max(0, used - g.bytesAtStart))
        }

        budgetStatus = try? agent.budget.status()
        networks = (try? store.allNetworks()) ?? []
    }

    // MARK: - Aktionen

    func setTier(_ newTier: PolicyTier?) {
        var state = store.policyState
        state.manualTier = newTier
        state.followNetwork = true
        try? store.savePolicyState(state)
        applyPolicy()
    }

    func setNetworkClass(_ cls: NetworkClass, for id: String? = nil) {
        let target = id ?? network.id
        guard target != "offline" else { return }
        try? store.setNetworkClass(cls, for: target)
        applyPolicy()
    }

    func block(_ service: Service, for duration: TimeInterval? = nil) {
        run { [agent] in
            try agent.coordinator.block(
                service, context: agent.context,
                reason: duration == nil ? .manual : .timer,
                until: duration.map { Date().addingTimeInterval($0) })
        }
    }

    func unblock(_ serviceId: String) {
        run { [agent] in try agent.coordinator.unblock(serviceId: serviceId) }
    }

    func grant(_ service: Service, for duration: TimeInterval) {
        run { [agent] in _ = try agent.policy.grant(service, duration: duration) }
    }

    func releaseAll() {
        run { [agent] in
            try agent.coordinator.emergencyRelease()
            var state = self.store.policyState
            state.manualTier = .off
            try self.store.savePolicyState(state)
        }
    }

    func applyPolicy() {
        isEnforcing = true
        work.async { [agent] in
            let result = Result { try agent.tickPolicy() }
            Task { @MainActor [weak self] in
                self?.isEnforcing = false
                switch result {
                case .success(let report): self?.needsRoot = report?.needsRoot ?? []
                case .failure(let error):  self?.lastError = error.localizedDescription
                }
                self?.reloadFromStore()
            }
        }
    }

    /// Zurück zur Automatik: Die Stufe folgt wieder der Einstufung des Netzes.
    func followNetwork() { setTier(nil) }

    /// Die Stufe, die das Netz von sich aus verlangen würde.
    var networkTier: PolicyTier { networkClass.defaultTier }

    /// Wurde die Stufe von Hand gewählt (oder von der Budget-Automatik)?
    var isManualTier: Bool { policyState.manualTier != nil }

    func setLanguage(_ preference: LanguagePreference) {
        L10n.setPreference(preference)
        languagePreference = preference
        language = L10n.language
    }

    func saveBudget(_ budget: Budget?) {
        try? store.saveBudget(budget)
        reloadFromStore()
    }

    // MARK: - Dauerbeobachtung

    /// Liste zurücksetzen — für einen Dienst oder ganz.
    func resetTracking(_ serviceId: String? = nil) {
        try? store.resetTracking(serviceId: serviceId)
        historyLoadedAt = .distantPast
        reloadFromStore()
    }

    func events(for serviceId: String) -> [ServiceEvent] {
        (try? store.events(serviceId: serviceId, limit: 100)) ?? []
    }

    func history(for serviceId: String, hours: Int, bucket: TimeInterval = 3600) -> [HistoryBucket] {
        (try? store.history(serviceId: serviceId,
                            since: Date().addingTimeInterval(-Double(hours) * 3600),
                            bucket: bucket)) ?? []
    }

    // MARK: - Profile bearbeiten

    var tierSummary: String { policyState.summary(for: tier) }

    func blockedClasses(for tier: PolicyTier) -> Set<ServiceClass> {
        policyState.blockedClasses(for: tier)
    }

    func toggleClass(_ cls: ServiceClass, for tier: PolicyTier) {
        var state = store.policyState
        var classes = state.blockedClasses(for: tier)
        if classes.contains(cls) { classes.remove(cls) } else { classes.insert(cls) }
        state.setBlockedClasses(classes, for: tier)
        try? store.savePolicyState(state)
        policyState = state
        applyPolicy()
    }

    func resetTier(_ tier: PolicyTier) {
        var state = store.policyState
        state.resetTier(tier)
        try? store.savePolicyState(state)
        policyState = state
        applyPolicy()
    }

    func setAutoEscalate(_ on: Bool) {
        var state = store.policyState
        state.autoEscalate = on
        try? store.savePolicyState(state)
        policyState = state
    }

    func setException(_ service: Service, allow: Bool?) {
        var state = store.policyState
        state.alwaysAllow.remove(service.id)
        state.alwaysBlock.remove(service.id)
        if allow == true { state.alwaysAllow.insert(service.id) }
        if allow == false { state.alwaysBlock.insert(service.id) }
        try? store.savePolicyState(state)
        policyState = state
        applyPolicy()
    }

    private func run(_ body: @escaping () throws -> Void) {
        isEnforcing = true
        work.async {
            let result = Result { try body() }
            Task { @MainActor [weak self] in
                self?.isEnforcing = false
                if case .failure(let error) = result {
                    self?.lastError = error.localizedDescription
                }
                self?.reloadFromStore()
            }
        }
    }

    // MARK: - Ableitungen für die Oberfläche

    /// Summe aller aktuellen Raten — das, was oben in der Menüleiste steht.
    ///
    /// Über die volle Liste, nicht über die gekürzte Live-Ansicht: Viele
    /// kleine Dienste ergeben zusammen durchaus etwas, und „—“ neben
    /// „10 aktiv“ wäre schlicht falsch.
    var currentRate: Double { tracked.reduce(0) { $0 + $1.rate } }

    var todayTotal: Int64 { tracked.reduce(0) { $0 + $1.todayBytes } }

    var activeCount: Int { tracked.filter { $0.isActive() }.count }

    /// Dienste, bei denen trotz Sperre Daten geflossen sind. Der wichtigste
    /// Hinweis, den diese App geben kann — eine Sperre, die nicht greift,
    /// ist schlimmer als keine, weil man sich auf sie verlässt.
    var leaking: [ServiceUsage] { tracked.filter { $0.attemptCount > 0 && $0.isBlocked } }

    /// Der Hinweis, der ganz oben in der Menüleiste steht, wenn etwas zu tun ist.
    var callToAction: String? {
        if networkClass == .unknown && !network.isOffline {
            return L("Dieses Netz ist noch nicht eingestuft — bis dahin wird nichts gesperrt.")
        }
        if !needsRoot.isEmpty {
            return L("Läuft trotz Profil weiter, weil dafür sudo nötig ist: %@",
                     andMore(needsRoot))
        }
        if !leaking.isEmpty {
            return L("Trotz Sperre aktiv: %@", andMore(leaking.map(\.service.displayName)))
        }
        if let status = budgetStatus, status.light == .red {
            return L("Verbrauch liegt über dem Tagesbudget.")
        }
        return nil
    }

    /// „A, B, C und 2 weitere" — die Liste bleibt eine Zeile lang.
    private func andMore(_ names: [String], limit: Int = 3) -> String {
        let shown = names.prefix(limit).joined(separator: ", ")
        guard names.count > limit else { return shown }
        return L("%@ und %@ weitere", shown, names.count - limit)
    }
}
