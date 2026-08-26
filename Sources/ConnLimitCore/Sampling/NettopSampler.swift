import Foundation

/// Liest Byte-Zähler pro Prozess aus `/usr/bin/nettop`.
///
/// Aufrufform: `nettop -x -P -L 1 -t <typ> -J bytes_in,bytes_out`
///   -x  maschinenlesbar (CSV)
///   -P  pro Prozess aggregiert statt pro Verbindung
///   -L 1 genau ein Sample, dann beenden
///   -t  Interface-Typ — **immer setzen**: ungefiltert zählt Traffic bei
///       aktivem VPN doppelt (einmal auf utun*, einmal auf dem physischen
///       Interface).
public struct NettopSampler {
    public var nettopPath: String
    public var linkType: LinkType

    public init(nettopPath: String = "/usr/bin/nettop", linkType: LinkType = .other) {
        self.nettopPath = nettopPath
        self.linkType = linkType
    }

    public func sample() throws -> [ProcessSample] {
        let out = try Shell.check(nettopPath,
            ["-x", "-P", "-L", "1", "-t", linkType.nettopFilter, "-J", "bytes_in,bytes_out"],
            timeout: 15)
        return Self.parse(out)
    }

    /// Parst die CSV-Ausgabe.
    ///
    /// ```
    /// ,bytes_in,bytes_out,
    /// apsd.363,557177,610194,
    /// Microsoft Outlo.55779,583544530,228686,
    /// ```
    /// Der Prozessname kann Punkte und Leerzeichen enthalten ("Google Chrome H.8241"),
    /// deshalb wird am **letzten** Punkt getrennt.
    public static func parse(_ text: String) -> [ProcessSample] {
        var result: [ProcessSample] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
                             .map { String($0) }
            // Kopfzeile beginnt mit leerem Feld, Datenzeilen mit "<name>.<pid>".
            guard fields.count >= 3, !fields[0].isEmpty else { continue }

            let token = fields[0]
            guard let dot = token.lastIndex(of: "."),
                  let pid = Int32(token[token.index(after: dot)...]) else { continue }
            let name = String(token[token.startIndex..<dot])
            guard let bytesIn = Int64(fields[1]), let bytesOut = Int64(fields[2]) else { continue }

            result.append(ProcessSample(name: name, pid: pid, bytesIn: bytesIn, bytesOut: bytesOut))
        }
        return result
    }
}
