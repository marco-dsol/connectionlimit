import Foundation

/// Löst PIDs zu vollem Pfad und Bundle-ID auf.
///
/// Nötig, weil nettop Prozessnamen auf 15 Zeichen kürzt ("Microsoft Outlo").
/// Ohne diesen Schritt wäre keine verlässliche Zuordnung zum Dienstkatalog
/// möglich.
public final class ProcessResolver {
    public struct Info: Sendable {
        public var pid: Int32
        public var executablePath: String
        public var bundleId: String?
        public var startedAt: String   // aus `ps lstart`, erkennt PID-Recycling

        public init(pid: Int32, executablePath: String, bundleId: String?, startedAt: String) {
            self.pid = pid
            self.executablePath = executablePath
            self.bundleId = bundleId
            self.startedAt = startedAt
        }
    }

    private var cache: [Int32: Info] = [:]

    public init() {}

    public func info(for pid: Int32) -> Info? {
        if let cached = cache[pid] { return cached }
        guard let fresh = load(pid: pid) else { return nil }
        cache[pid] = fresh
        return fresh
    }

    /// PIDs entfernen, die es nicht mehr gibt. Verhindert, dass eine recycelte
    /// PID die Kennung des Vorgängers erbt.
    public func prune(livePIDs: Set<Int32>) {
        cache = cache.filter { livePIDs.contains($0.key) }
    }

    private func load(pid: Int32) -> Info? {
        guard let out = try? Shell.run("/bin/ps", ["-p", "\(pid)", "-o", "comm=,lstart="]),
              out.ok else { return nil }
        let line = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        // `ps -o comm=,lstart=` liefert den Pfad, gefolgt vom festformatierten
        // Startdatum ("Mon Aug 25 16:28:11 2026" — immer 5 Felder). Der Pfad
        // selbst kann Leerzeichen enthalten, deshalb wird von hinten getrennt.
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        let path: String
        let started: String
        if parts.count > 5 {
            started = parts.suffix(5).joined(separator: " ")
            path = parts.dropLast(5).joined(separator: " ")
        } else {
            started = ""
            path = line
        }

        return Info(pid: pid,
                    executablePath: path,
                    bundleId: Self.bundleId(forExecutablePath: path),
                    startedAt: started)
    }

    /// Bundle-ID aus dem Executable-Pfad ableiten:
    /// `/Applications/Foo.app/Contents/MacOS/Foo` → Info.plist des Bundles.
    static func bundleId(forExecutablePath path: String) -> String? {
        guard let range = path.range(of: ".app/Contents/MacOS/") else { return nil }
        let bundlePath = String(path[path.startIndex..<range.lowerBound]) + ".app"
        return Bundle(path: bundlePath)?.bundleIdentifier
    }
}
