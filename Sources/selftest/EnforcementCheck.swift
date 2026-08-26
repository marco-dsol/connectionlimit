import Foundation
import ConnLimitCore

/// Prüft den riskantesten Pfad des Werkzeugs am lebenden Objekt: einen Prozess
/// einfrieren und wieder auftauen.
///
/// Ein eingefrorener Prozess, der nie SIGCONT bekommt, wäre der schlimmste
/// Fehler dieser App — deshalb wird das nicht simuliert, sondern echt geprüft.
/// Als Versuchsobjekt dient ein eindeutig benannter **Symlink** auf
/// `/bin/sleep`, damit kein fremder `sleep` getroffen werden kann. Eine Kopie
/// wäre einfacher, funktioniert aber nicht: das Duplikat verliert seinen
/// Platform-Binary-Status und wird beim Start sofort per SIGKILL beendet.
func checkEnforcementRoundTrip(_ t: Harness) {
    t.suite("Einfrieren und Auftauen (echter Prozess)") {
        let unique = "connlimit-testschlaefer-\(UUID().uuidString.prefix(8))"
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(unique, isDirectory: true)
        let binary = dir.appendingPathComponent(unique)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: binary.path,
                                                   withDestinationPath: "/bin/sleep")
        defer { try? FileManager.default.removeItem(at: dir) }

        let victim = Process()
        victim.executableURL = binary
        victim.arguments = ["45"]
        try victim.run()
        defer { if victim.isRunning { victim.terminate() } }

        // Kurz warten, bis der Prozess in der Prozessliste steht.
        Thread.sleep(forTimeInterval: 0.4)
        let pid = victim.processIdentifier

        let service = Service(
            id: "selftest-victim", name: "Testschläfer", serviceClass: .sync,
            match: ServiceMatch(processes: [unique], pathPrefixes: [dir.path]),
            levers: [.processFreeze])

        let found = ProcessLookup.pids(for: service)
        t.expect(found.contains(pid), "Prozesssuche findet den Testprozess (PID \(pid))")

        let enforcer = ProcessFreezeEnforcer()
        let context = EnforcementContext(network: .offline, livePIDs: [:])
        t.expect(enforcer.canEnforce(service, spec: .processFreeze, context: context),
                 "Hebel meldet sich für einen laufenden Prozess als anwendbar")

        var receipt = EnforcementReceipt(serviceId: service.id, lever: .processFreeze,
                                         payload: .init())
        do {
            try enforcer.apply(service, spec: .processFreeze, receipt: &receipt, context: context)
        } catch {
            t.expect(false, "Einfrieren warf: \(error)")
            return
        }
        t.expect(receipt.payload.pids.contains(pid), "Quittung hält die eingefrorene PID fest")

        Thread.sleep(forTimeInterval: 0.2)
        t.expectEqual(processState(pid), "T", "Prozess ist angehalten (ps-Status T)")

        try enforcer.revert(receipt)
        Thread.sleep(forTimeInterval: 0.2)
        let after = processState(pid)
        t.expect(after == "S" || after == "R" || after == "I",
                 "Prozess läuft nach dem Auftauen wieder (Status \(after))")

        // Idempotenz: Recovery ruft revert blind auf, auch für längst
        // beendete Prozesse. Das darf nicht werfen.
        victim.terminate()
        victim.waitUntilExit()
        var thrown = false
        do { try enforcer.revert(receipt) } catch { thrown = true }
        t.expect(!thrown, "Freigeben eines längst beendeten Prozesses wirft nicht")
    }
}

private func processState(_ pid: Int32) -> String {
    guard let r = try? Shell.run("/bin/ps", ["-p", "\(pid)", "-o", "state="]), r.ok else {
        return "?"
    }
    let s = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(s.prefix(1))
}
