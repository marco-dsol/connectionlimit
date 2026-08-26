import Foundation

/// Friert Nutzer-Apps per SIGSTOP ein.
///
/// **Ehrlich gesagt:** das stoppt nicht nur den Netzverkehr, sondern die ganze
/// App. Für reine Sync-Clients (OneDrive, Dropbox, Nextcloud) ist genau das
/// gewollt. Für Mail oder Browser ist es grob — die UI weist darauf hin.
///
/// Ohne Entitlement gibt es auf macOS keinen Userland-Weg, einer App nur das
/// Netz zu entziehen. Siehe `.knowledgebase/01-macos-technik.md`, Abschnitt C.
public final class ProcessFreezeEnforcer: Enforcer {
    public let kind: LeverKind = .processFreeze
    public init() {}

    public func canEnforce(_ service: Service, spec: LeverSpec, context: EnforcementContext) -> Bool {
        guard case .processFreeze = spec else { return false }
        return !pids(for: service, context: context).isEmpty
    }

    public func apply(_ service: Service, spec: LeverSpec, receipt: inout EnforcementReceipt,
                      context: EnforcementContext) throws {
        let targets = pids(for: service, context: context)
        guard !targets.isEmpty else { throw EnforcementError.noApplicableLever(service.name) }

        var frozen: [Int32] = []
        for pid in targets {
            if kill(pid, SIGSTOP) == 0 {
                frozen.append(pid)
            } else if errno == EPERM {
                // Fremder Nutzer oder SIP-geschützt — kein Grund, den Rest
                // aufzugeben, aber der Nutzer soll es erfahren.
                FileHandle.standardError.write(
                    "connlimit: PID \(pid) (\(service.name)) darf nicht eingefroren werden\n".data(using: .utf8)!)
            }
        }
        guard !frozen.isEmpty else {
            throw EnforcementError.leverFailed(.processFreeze, "keine PID konnte eingefroren werden")
        }
        receipt.payload.pids = frozen
    }

    public func revert(_ receipt: EnforcementReceipt) throws {
        for pid in receipt.payload.pids {
            // Prozess kann längst beendet sein — das ist kein Fehler.
            _ = kill(pid, SIGCONT)
        }
    }

    private func pids(for service: Service, context: EnforcementContext) -> [Int32] {
        let candidates: [Int32]
        if let known = context.livePIDs[service.id], !known.isEmpty {
            candidates = known
        } else {
            candidates = ProcessLookup.pids(for: service)
        }
        // Nie den eigenen Prozess oder einen seiner Vorfahren einfrieren —
        // sonst friert das Werkzeug die Hand ein, die es bedient, und niemand
        // kann die Sperre mehr aufheben.
        let protected = ProcessLookup.protectedPIDs()
        return candidates.filter { !protected.contains($0) }
    }
}
