import Foundation

/// Ruft das App-eigene Pause-Kommando auf — der freundlichste Hebel, weil die
/// App bedienbar bleibt. Nur für Dienste verfügbar, die so ein Kommando haben.
public final class AppPauseEnforcer: Enforcer {
    public let kind: LeverKind = .appPause
    public init() {}

    public func canEnforce(_ service: Service, spec: LeverSpec, context: EnforcementContext) -> Bool {
        guard case .appPause(let command, _) = spec, let tool = command.first else { return false }
        return FileManager.default.isExecutableFile(atPath: tool)
            && !ProcessLookup.pids(for: service).isEmpty
    }

    public func apply(_ service: Service, spec: LeverSpec, receipt: inout EnforcementReceipt,
                      context: EnforcementContext) throws {
        guard case .appPause(let command, let resume) = spec, let tool = command.first else {
            throw EnforcementError.leverFailed(.appPause, "falscher Hebel-Typ")
        }
        let r = try Shell.run(tool, Array(command.dropFirst()))
        guard r.ok else {
            throw EnforcementError.leverFailed(.appPause, r.stderr.isEmpty ? r.stdout : r.stderr)
        }
        receipt.payload.resumeCommand = resume
    }

    public func revert(_ receipt: EnforcementReceipt) throws {
        guard let resume = receipt.payload.resumeCommand, let tool = resume.first else { return }
        _ = try? Shell.run(tool, Array(resume.dropFirst()))
    }
}
