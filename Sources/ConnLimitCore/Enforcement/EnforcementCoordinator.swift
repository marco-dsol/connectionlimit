import Foundation

/// Wählt für jeden Dienst den besten verfügbaren Hebel und verwaltet die
/// Quittungen.
public final class EnforcementCoordinator {
    private let store: Store
    private let catalog: ServiceCatalog
    private let enforcers: [LeverKind: Enforcer]

    public init(store: Store, catalog: ServiceCatalog,
                enforcers: [Enforcer] = EnforcementCoordinator.defaultEnforcers()) {
        self.store = store
        self.catalog = catalog
        self.enforcers = Dictionary(uniqueKeysWithValues: enforcers.map { ($0.kind, $0) })
    }

    public static func defaultEnforcers() -> [Enforcer] {
        [AppPauseEnforcer(), LaunchdFreezeEnforcer(), PFEnforcer(), ProcessFreezeEnforcer()]
    }

    // MARK: - Zustand

    public func blockedServiceIds() throws -> Set<String> {
        try store.blockedServiceIds()
    }

    public func receipts(for serviceId: String) throws -> [EnforcementReceipt] {
        try store.openReceipts().filter { $0.serviceId == serviceId }
    }

    // MARK: - Sperren

    @discardableResult
    public func block(_ service: Service, context: EnforcementContext,
                      reason: EnforcementReceipt.Reason = .manual,
                      until: Date? = nil) throws -> EnforcementReceipt {
        guard service.serviceClass.isBlockable else {
            throw EnforcementError.notBlockable(service.name)
        }
        // Bereits gesperrt: nicht doppelt sperren, aber die Absicht nachziehen.
        //
        // Wer einen Dienst von Hand sperrt, den gerade das Profil hält, meint
        // „auch ohne Profil" — sonst höbe der nächste Profilwechsel die Sperre
        // stillschweigend auf. Und „jetzt sperren" nach einer befristeten
        // Sperre heißt „ab jetzt ohne Frist". Eine Profil-Sperre ändert
        // dagegen nie eine bewusst gesetzte.
        if var existing = try receipts(for: service.id).first {
            guard reason != .profile else { return existing }
            let upgraded = existing.reason == .profile || existing.reason != reason
            if upgraded || existing.expiresAt != until {
                existing.reason = reason
                existing.expiresAt = until
                try store.save(existing)
            }
            return existing
        }

        for spec in service.levers {
            guard let enforcer = enforcers[spec.kind],
                  enforcer.canEnforce(service, spec: spec, context: context) else { continue }

            var receipt = EnforcementReceipt(
                serviceId: service.id, lever: spec.kind, payload: .init(),
                expiresAt: until, networkId: context.network.id, reason: reason)

            // Quittung VOR dem Eingriff speichern. Ein Absturz dazwischen
            // hinterlässt eine wirkungslose Quittung (harmlos). Umgekehrt bliebe
            // eine eingefrorene App ohne Spur zurück.
            try store.save(receipt)
            do {
                try enforcer.apply(service, spec: spec, receipt: &receipt, context: context)
                try store.save(receipt)   // mit gefüllter Payload
                // Zeitpunkt festhalten: ohne Protokoll ließe sich hinterher
                // nicht mehr sagen, seit wann ein Dienst stillsteht.
                _ = try? store.logEvent(.blocked, serviceId: service.id,
                                    detail: "\(spec.kind.rawValue) · \(reason.rawValue)")
                return receipt
            } catch {
                try? store.deleteReceipt(id: receipt.id)
                // Nächsten Hebel probieren statt sofort aufzugeben.
                continue
            }
        }
        throw EnforcementError.noApplicableLever(service.name)
    }

    // MARK: - Freigeben

    public func unblock(serviceId: String) throws {
        for receipt in try receipts(for: serviceId) {
            try revert(receipt)
        }
    }

    public func revert(_ receipt: EnforcementReceipt) throws {
        if let enforcer = enforcers[receipt.lever] {
            try enforcer.revert(receipt)
        }
        try store.deleteReceipt(id: receipt.id)
        // Sprachneutral gespeichert; `ServiceEvent.displayDetail` macht daraus
        // „gesperrt seit …" in der Sprache, die gerade gilt.
        _ = try? store.logEvent(.released, serviceId: receipt.serviceId,
                            detail: "since:\(Int64(receipt.createdAt.timeIntervalSince1970))")
    }

    public func unblockAll() throws {
        var failures: [String] = []
        for receipt in try store.openReceipts() {
            do { try revert(receipt) }
            catch { failures.append("\(receipt.serviceId): \(error.localizedDescription)") }
        }
        if !failures.isEmpty {
            throw EnforcementError.leverFailed(.processFreeze, failures.joined(separator: "; "))
        }
    }

    // MARK: - Wiederherstellung nach Absturz

    /// Beim Start aufzurufen. Alles, was der letzte Lauf hinterlassen hat, wird
    /// entweder als gültig bestätigt oder aufgeräumt.
    ///
    /// Regel: **im Zweifel freigeben.** Eine übersehene Sperre wäre schlimmer
    /// als eine zu früh aufgehobene — eine für immer eingefrorene App ist der
    /// schlimmste denkbare Fehler dieses Werkzeugs.
    @discardableResult
    public func recover(context: EnforcementContext, activeTier: PolicyTier) throws -> [String] {
        var released: [String] = []
        for receipt in try store.openReceipts() {
            var shouldRelease = false
            var why = ""

            if receipt.isExpired {
                shouldRelease = true; why = L("Timer abgelaufen")
            } else if receipt.reason == .profile && activeTier == .off {
                shouldRelease = true; why = L("Profil ist nicht mehr aktiv")
            } else if receipt.lever == .processFreeze,
                      !receipt.payload.pids.contains(where: ProcessLookup.isAlive) {
                shouldRelease = true; why = L("Prozesse existieren nicht mehr")
            } else if receipt.lever == .pfDomains, let net = receipt.networkId,
                      net != context.network.id {
                shouldRelease = true; why = L("Regel galt für ein anderes Netz")
            }

            if shouldRelease {
                try? revert(receipt)
                released.append("\(receipt.serviceId) (\(why))")
            }
        }
        return released
    }

    /// Not-Aus: alle Sperren aufheben, unabhängig von Quittungen. Wird auch vom
    /// Boot-Wächter benutzt.
    public func emergencyRelease() throws {
        try? unblockAll()
        if Shell.isRoot { try? PFAnchor.flushAll() }
    }
}
