import Foundation
import ConnLimitCore

/// Gemeinsamer Aufbau für alle Befehle.
struct App {
    let store: Store
    let catalog: ServiceCatalog
    let agent: Agent
    let coordinator: EnforcementCoordinator
    let policy: PolicyEngine
    let budget: BudgetTracker

    init(config: Agent.Config = Agent.Config()) throws {
        store = try Store()
        catalog = ServiceCatalog.load(userFile: Store.catalogPath)
        agent = Agent(store: store, catalog: catalog, config: config)
        coordinator = agent.coordinator
        policy = agent.policy
        budget = agent.budget
    }

    /// Findet einen Dienst über id, Name oder Teilstring — Tippfreundlichkeit
    /// zählt hier mehr als Strenge.
    func service(matching query: String) throws -> Service {
        let q = query.lowercased()
        if let exact = catalog.service(id: query) { return exact }
        // Name in beiden Sprachen: „iCloud Fotos" und „iCloud Photos" meinen
        // denselben Dienst, egal wie das Terminal gerade eingestellt ist.
        func names(_ s: Service) -> [String] { [s.name.lowercased(), s.displayName.lowercased()] }
        let byName = catalog.services.filter { names($0).contains(q) }
        if let hit = byName.first { return hit }

        let partial = catalog.services.filter {
            $0.id.lowercased().contains(q) || names($0).contains { $0.contains(q) }
        }
        if partial.count == 1 { return partial[0] }
        if partial.count > 1 {
            let names = partial.prefix(8).map { "\($0.id) (\($0.displayName))" }.joined(separator: "\n  ")
            throw CLIError.notFound(L("'%@' ist mehrdeutig:", query) + "\n  \(names)")
        }
        throw CLIError.notFound(L("Kein Dienst gefunden für '%@'. 'connlimit services' zeigt alle.", query))
    }

    /// Wie `service(matching:)`, sucht aber auch unter den beobachteten
    /// Diensten. Ein Prozess, den der Katalog nicht kennt, steht in der Liste
    /// und muss sich von dort aus auch ansprechen lassen.
    func serviceOrTracked(matching query: String) throws -> Service {
        if let hit = try? service(matching: query) { return hit }
        let q = query.lowercased()
        let tracked = try store.trackedServices().map { catalog.serviceOrUnknown(id: $0.serviceId) }
        let matches = tracked.filter {
            $0.id.lowercased().contains(q) || $0.name.lowercased().contains(q)
                || $0.displayName.lowercased().contains(q)
        }
        if matches.count == 1 { return matches[0] }
        if matches.count > 1 {
            let names = matches.prefix(8).map { "\($0.id) (\($0.displayName))" }.joined(separator: "\n  ")
            throw CLIError.notFound(L("'%@' ist mehrdeutig:", query) + "\n  \(names)")
        }
        throw CLIError.notFound(L("Kein Dienst gefunden für '%@'. 'connlimit tracked' zeigt die beobachteten, 'connlimit services' den Katalog.", query))
    }

    /// Netz einmalig ermitteln und in der Datenbank festhalten.
    @discardableResult
    func refreshNetwork() throws -> (identity: NetworkIdentity, class: NetworkClass) {
        let (identity, cls, _) = try agent.refreshNetwork()
        return (identity, cls)
    }
}
