import Foundation

/// Findet laufende Prozesse zu einem Dienst.
public enum ProcessLookup {

    public struct Entry: Sendable {
        public var pid: Int32
        public var command: String   // voller Pfad
    }

    public static func running() -> [Entry] {
        guard let out = try? Shell.run("/bin/ps", ["-axo", "pid=,comm="]), out.ok else { return [] }
        var entries: [Entry] = []
        for line in out.stdout.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let space = trimmed.firstIndex(of: " "),
                  let pid = Int32(trimmed[trimmed.startIndex..<space]) else { continue }
            let command = String(trimmed[trimmed.index(after: space)...])
                .trimmingCharacters(in: .whitespaces)
            entries.append(Entry(pid: pid, command: command))
        }
        return entries
    }

    /// PIDs, die zu diesem Dienst gehören.
    ///
    /// Bewusst konservativ: nur exakter Basename oder Pfad-Präfix. Ein
    /// `pgrep -f`-artiger Substring-Treffer würde bei einem Dienst namens
    /// "Mail" halb System einfrieren.
    public static func pids(for service: Service, in entries: [Entry]? = nil) -> [Int32] {
        let list = entries ?? running()
        let names = Set(service.match.processes.map { $0.lowercased() })
        let prefixes = service.match.pathPrefixes

        var result: [Int32] = []
        for e in list {
            let base = (e.command as NSString).lastPathComponent.lowercased()
            if names.contains(base) { result.append(e.pid); continue }
            if prefixes.contains(where: { e.command.hasPrefix($0) }) { result.append(e.pid) }
        }
        return result
    }

    public static func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    // MARK: - Selbstschutz

    /// Prozesse, die dieses Werkzeug niemals einfrieren darf: der eigene und
    /// jeder, von dem er abstammt.
    ///
    /// Das ist kein theoretischer Fall. Wird das Werkzeug aus einem Terminal
    /// heraus benutzt, ist dieses Terminal ein Vorfahre — und ein
    /// eingefrorenes Terminal kann den Befehl zum Auftauen nicht mehr
    /// absetzen. Dasselbe gilt für jede Oberfläche, die die App startet.
    /// Die Sperre wäre dann nicht mehr rückgängig zu machen, und genau das
    /// ist der schlimmste denkbare Fehler dieses Werkzeugs.
    ///
    /// Die Abstammung wird bei jedem Aufruf frisch bestimmt: Sie ändert sich
    /// nicht, aber ein zwischengespeicherter Wert, der einmal falsch ist,
    /// wäre hier teurer als der `ps`-Aufruf.
    public static func protectedPIDs() -> Set<Int32> {
        var result: Set<Int32> = [getpid()]
        var parents: [Int32: Int32] = [:]

        if let out = try? Shell.run("/bin/ps", ["-axo", "pid=,ppid="]), out.ok {
            for line in out.stdout.split(separator: "\n") {
                let fields = line.split(separator: " ", omittingEmptySubsequences: true)
                guard fields.count >= 2,
                      let pid = Int32(fields[0]), let ppid = Int32(fields[1]) else { continue }
                parents[pid] = ppid
            }
        }

        var current = getppid()
        // Bis zu `launchd` (PID 1) hinauf; die Schleifenbremse schützt vor
        // einer kaputten Prozesstabelle.
        var hops = 0
        while current > 1 && hops < 64 {
            result.insert(current)
            guard let next = parents[current] else { break }
            current = next
            hops += 1
        }
        return result
    }
}
