import Foundation

/// Friert launchd-Jobs ein: `launchctl kill SIGSTOP system/<label>`.
///
/// Der sauberste Hebel für Apple-Hintergrunddienste — er stoppt das Volumen an
/// der Quelle und hinterlässt nichts auf der Platte. Bewusst SIGSTOP statt
/// `bootout`: SIP schützt viele Apple-Daemons vor dem Entladen, gegen SIGSTOP
/// aber nicht.
public final class LaunchdFreezeEnforcer: Enforcer {
    public let kind: LeverKind = .launchdFreeze
    private let launchctl = "/bin/launchctl"

    public init() {}

    public func canEnforce(_ service: Service, spec: LeverSpec, context: EnforcementContext) -> Bool {
        guard case .launchdFreeze(let jobs) = spec, !jobs.isEmpty else { return false }
        guard Shell.isRoot else { return false }
        return jobs.contains { isLoaded($0) }
    }

    public func apply(_ service: Service, spec: LeverSpec, receipt: inout EnforcementReceipt,
                      context: EnforcementContext) throws {
        guard case .launchdFreeze(let jobs) = spec else {
            throw EnforcementError.leverFailed(.launchdFreeze, L("falscher Hebel-Typ"))
        }
        guard Shell.isRoot else { throw EnforcementError.needsRoot(.launchdFreeze) }

        var stopped: [String] = []
        for job in jobs {
            let r = try Shell.run(launchctl, ["kill", "SIGSTOP", "system/\(job)"])
            if r.ok { stopped.append(job) }
        }
        guard !stopped.isEmpty else {
            throw EnforcementError.leverFailed(.launchdFreeze, L("kein Job konnte gestoppt werden"))
        }
        receipt.payload.jobs = stopped
    }

    public func revert(_ receipt: EnforcementReceipt) throws {
        guard Shell.isRoot else { throw EnforcementError.needsRoot(.launchdFreeze) }
        for job in receipt.payload.jobs {
            _ = try? Shell.run(launchctl, ["kill", "SIGCONT", "system/\(job)"])
        }
    }

    private func isLoaded(_ job: String) -> Bool {
        (try? Shell.run(launchctl, ["print", "system/\(job)"]))?.ok ?? false
    }
}
