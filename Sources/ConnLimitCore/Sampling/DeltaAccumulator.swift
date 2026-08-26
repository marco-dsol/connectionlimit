import Foundation

/// Bildet aus den kumulativen nettop-Zählern Zuwächse.
///
/// Die Zähler laufen ab Socket-/Prozessstart, nicht ab Boot, und sind über
/// einen PID-Wechsel hinweg nicht monoton. Deshalb:
///
/// - Sinkt ein Zähler, gilt der Prozess als neu gestartet: die Serie wird
///   zurückgesetzt statt negativ verrechnet.
/// - Verschwindet eine PID, wird ihr Eintrag verworfen. Ihr letzter,
///   nicht abgeholter Zuwachs geht verloren — das ist der bekannte blinde
///   Fleck des Verfahrens.
public final class DeltaAccumulator {
    private var previous: [String: ProcessSample] = [:]
    private var lastSampleAt: Date?

    public init() {}

    public struct Result: Sendable {
        public var deltas: [ProcessSample]     // hier: Zuwächse, nicht Absolutwerte
        public var interval: TimeInterval
        public var livePIDs: Set<Int32>
    }

    public func ingest(_ samples: [ProcessSample], at now: Date = Date()) -> Result {
        let interval = lastSampleAt.map { now.timeIntervalSince($0) } ?? 0
        lastSampleAt = now

        var deltas: [ProcessSample] = []
        var current: [String: ProcessSample] = [:]
        var pids = Set<Int32>()

        for s in samples {
            current[s.key] = s
            pids.insert(s.pid)

            guard let prev = previous[s.key] else {
                // Erstsichtung: der bereits aufgelaufene Zählerstand gehört zur
                // Vergangenheit und darf nicht als Zuwachs verbucht werden.
                continue
            }
            let dIn = s.bytesIn - prev.bytesIn
            let dOut = s.bytesOut - prev.bytesOut
            guard dIn >= 0, dOut >= 0 else { continue }   // Zähler-Reset
            guard dIn > 0 || dOut > 0 else { continue }

            deltas.append(ProcessSample(name: s.name, pid: s.pid, bytesIn: dIn, bytesOut: dOut))
        }

        previous = current
        return Result(deltas: deltas, interval: interval, livePIDs: pids)
    }

    public func reset() {
        previous.removeAll()
        lastSampleAt = nil
    }
}
