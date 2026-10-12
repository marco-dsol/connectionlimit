import Foundation

/// Verfolgt den Reiseverbrauch und schlägt Eskalationen vor.
public final class BudgetTracker {
    private let store: Store

    public init(store: Store) { self.store = store }

    /// Nur teure Netze zählen gegen das Budget.
    public static let countedClasses: Set<NetworkClass> = [.metered, .limited]

    public func status() throws -> BudgetStatus? {
        guard let budget = store.budget else { return nil }
        let used = try store.totalBytes(since: budget.startsAt,
                                        networkClasses: Self.countedClasses)
        let today = try store.totalBytes(since: Calendar.current.startOfDay(for: Date()),
                                         networkClasses: Self.countedClasses)
        return BudgetStatus(budget: budget, usedBytes: used, usedTodayBytes: today)
    }

    public struct Escalation: Sendable {
        public var newTier: PolicyTier
        public var reason: String
    }

    /// Prüft, ob hochgestuft werden muss.
    ///
    /// Es geht bewusst nur **hoch**, nie automatisch runter (außer beim Wechsel
    /// in ein freies Netz, den die PolicyEngine erledigt). Sonst würde das
    /// System zwischen zwei Stufen pendeln, sobald der Verbrauch um die
    /// Schwelle schwankt.
    public func escalation(from current: PolicyTier) throws -> Escalation? {
        guard store.policyState.autoEscalate, let status = try status() else { return nil }

        if status.remainingFraction < 0.05, current < .emergency {
            return Escalation(newTier: .emergency,
                              reason: L("Weniger als 5 % des Volumens übrig — Notfallbetrieb."))
        }
        if status.remainingFraction < 0.15, current < .emergency {
            return Escalation(newTier: .emergency,
                              reason: L("Weniger als 15 % des Volumens übrig."))
        }
        if status.light == .red, current < .vacation {
            return Escalation(newTier: .vacation,
                              reason: L("Hochrechnung liegt über dem Tagesbudget (%@ statt %@).",
                                        ByteFormat.short(status.projectedToday),
                                        ByteFormat.short(status.dailyAllowance)))
        }
        return nil
    }
}
