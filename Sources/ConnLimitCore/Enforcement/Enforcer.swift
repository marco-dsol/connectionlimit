import Foundation

public enum EnforcementError: Error, LocalizedError {
    case notBlockable(String)
    case noApplicableLever(String)
    case needsRoot(LeverKind)
    case leverFailed(LeverKind, String)
    case pfAnchorMissing

    public var errorDescription: String? {
        switch self {
        case .notBlockable(let name):
            return L("'%@' ist als systemkritisch eingestuft und kann nicht gesperrt werden.", L(name))
        case .noApplicableLever(let name):
            return L("Für '%@' greift gerade kein Hebel (läuft der Dienst überhaupt?).", L(name))
        case .needsRoot(let lever):
            return L("Der Hebel '%@' braucht root — bitte mit sudo starten.", lever.displayName)
        case .leverFailed(let lever, let msg):
            return L("Hebel '%@' fehlgeschlagen: %@", lever.displayName, msg)
        case .pfAnchorMissing:
            return L("PF-Anchor ist nicht installiert. Einmalig 'sudo connlimit install-pf' ausführen.")
        }
    }
}

public struct EnforcementContext: Sendable {
    public var network: NetworkIdentity
    /// PIDs pro Dienst aus dem letzten Sampling — spart ein eigenes `ps`.
    public var livePIDs: [String: [Int32]]

    public init(network: NetworkIdentity, livePIDs: [String: [Int32]] = [:]) {
        self.network = network
        self.livePIDs = livePIDs
    }
}

public protocol Enforcer: AnyObject {
    var kind: LeverKind { get }
    /// Kann dieser Hebel den Dienst gerade bedienen?
    func canEnforce(_ service: Service, spec: LeverSpec, context: EnforcementContext) -> Bool
    /// Setzt die Sperre. Die Quittung ist bereits gespeichert.
    func apply(_ service: Service, spec: LeverSpec, receipt: inout EnforcementReceipt,
               context: EnforcementContext) throws
    /// Hebt die Sperre auf. Muss idempotent sein: ein Aufruf für etwas, das
    /// bereits weg ist, darf nicht werfen — Recovery ruft das blind auf.
    func revert(_ receipt: EnforcementReceipt) throws
}
