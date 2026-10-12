import Foundation

/// Entscheidet, welche Dienste gerade gesperrt sein sollen, und bringt den
/// tatsächlichen Zustand mit dieser Entscheidung in Übereinstimmung.
public final class PolicyEngine {
    private let store: Store
    private let catalog: ServiceCatalog
    private let coordinator: EnforcementCoordinator

    public init(store: Store, catalog: ServiceCatalog, coordinator: EnforcementCoordinator) {
        self.store = store
        self.catalog = catalog
        self.coordinator = coordinator
    }

    /// Die Stufe, die gerade gelten soll.
    public func effectiveTier(networkClass: NetworkClass) -> PolicyTier {
        let state = store.policyState
        // In freien Netzen greift nichts — auch keine manuell gesetzte Stufe.
        // Sonst würde ein vergessener Urlaubsmodus zu Hause weiterlaufen.
        if state.followNetwork && networkClass == .free { return .off }
        if let manual = state.manualTier { return manual }
        guard state.followNetwork else { return .off }
        return networkClass.defaultTier
    }

    public struct Decision: Sendable {
        public var tier: PolicyTier
        public var shouldBlock: [Service]
        public var shouldAllow: [Service]
    }

    /// Welche Dienste gehören auf dieser Stufe gesperrt?
    public func decide(tier: PolicyTier, activeGrants: Set<String>) -> Decision {
        let state = store.policyState
        let blockedClasses = state.blockedClasses(for: tier)

        var toBlock: [Service] = []
        var toAllow: [Service] = []

        for service in catalog.services {
            guard service.isBlockable else { toAllow.append(service); continue }

            var wanted = blockedClasses.contains(service.serviceClass)
            if state.alwaysBlock.contains(service.id) { wanted = true }
            if state.alwaysAllow.contains(service.id) { wanted = false }
            if activeGrants.contains(service.id) { wanted = false }   // Timer-Freigabe schlägt alles

            if wanted { toBlock.append(service) } else { toAllow.append(service) }
        }
        return Decision(tier: tier, shouldBlock: toBlock, shouldAllow: toAllow)
    }

    public struct SyncReport: Sendable {
        public var tier: PolicyTier
        public var blocked: [String] = []
        public var released: [String] = []
        public var failed: [(service: String, reason: String)] = []
        /// Dienste, die das Profil sperren würde, für die aber alle Hebel root
        /// brauchen. Ohne diesen Hinweis würde die Oberfläche „Urlaubsmodus
        /// aktiv" melden, während die größten Posten weiterlaufen.
        public var needsRoot: [String] = []
    }

    /// Bringt die Wirklichkeit mit der Entscheidung in Deckung.
    @discardableResult
    public func apply(networkClass: NetworkClass, context: EnforcementContext) throws -> SyncReport {
        try expireGrants()
        try expireTimers()

        let tier = effectiveTier(networkClass: networkClass)
        let grants = Set(try store.grants().filter { !$0.isExpired }.map(\.serviceId))
        let decision = decide(tier: tier, activeGrants: grants)
        let currentlyBlocked = try coordinator.blockedServiceIds()

        var report = SyncReport(tier: tier)

        for service in decision.shouldBlock where !currentlyBlocked.contains(service.id) {
            do {
                try coordinator.block(service, context: context, reason: .profile)
                report.blocked.append(service.displayName)
            } catch EnforcementError.noApplicableLever {
                // Zwei sehr verschiedene Fälle sehen hier gleich aus: der
                // Dienst läuft gerade nicht (harmlos), oder alle seine Hebel
                // brauchen root, das wir nicht haben (nicht harmlos — der
                // Nutzer glaubt sonst, es sei gesperrt).
                if !Shell.isRoot && service.levers.allSatisfy({ $0.kind.needsRoot }) {
                    report.needsRoot.append(service.displayName)
                }
                continue
            } catch {
                report.failed.append((service.displayName, error.localizedDescription))
            }
        }

        // Nur Profil-Sperren wieder aufheben. Manuelle Sperren und Timer bleiben.
        for receipt in try store.openReceipts()
        where receipt.reason == .profile && !decision.shouldBlock.contains(where: { $0.id == receipt.serviceId }) {
            try? coordinator.revert(receipt)
            report.released.append(catalog.serviceOrUnknown(id: receipt.serviceId).displayName)
        }

        return report
    }

    // MARK: - Timer

    /// Freigabe auf Zeit: Dienst wird entsperrt und läuft nach `duration`
    /// automatisch wieder ins Profil zurück.
    @discardableResult
    public func grant(_ service: Service, duration: TimeInterval) throws -> Grant {
        let used = (try? store.serviceTotal(service.id)) ?? 0
        let grant = Grant(serviceId: service.id,
                          until: Date().addingTimeInterval(duration),
                          bytesAtStart: used)
        try store.save(grant)
        try coordinator.unblock(serviceId: service.id)
        return grant
    }

    /// Abgelaufene Freigaben schließen. Liefert zurück, was sie gekostet haben —
    /// diese Rückmeldung ist der eigentliche Lerneffekt für den Nutzer.
    @discardableResult
    public func expireGrants() throws -> [(service: String, bytes: Int64)] {
        var closed: [(String, Int64)] = []
        for grant in try store.grants() where grant.isExpired {
            let now = (try? store.serviceTotal(grant.serviceId)) ?? 0
            let spent = max(0, now - grant.bytesAtStart)
            let name = catalog.serviceOrUnknown(id: grant.serviceId).displayName
            closed.append((name, spent))
            try store.deleteGrant(id: grant.id)
        }
        return closed
    }

    /// Abgelaufene befristete Sperren aufheben.
    @discardableResult
    public func expireTimers() throws -> [String] {
        var lifted: [String] = []
        for receipt in try store.openReceipts() where receipt.isExpired {
            try? coordinator.revert(receipt)
            lifted.append(catalog.serviceOrUnknown(id: receipt.serviceId).displayName)
        }
        return lifted
    }
}
