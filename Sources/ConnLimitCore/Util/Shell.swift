import Foundation

public struct ShellResult: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String
    public var ok: Bool { status == 0 }
}

public enum ShellError: Error, LocalizedError {
    case launchFailed(String, Error)
    case failed(String, Int32, String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let cmd, let err):
            return L("Konnte '%@' nicht starten: %@", cmd, err.localizedDescription)
        case .failed(let cmd, let status, let err):
            return L("'%@' fehlgeschlagen (Status %@): %@", cmd, status, err)
        }
    }
}

public enum Shell {
    /// Führt ein Kommando aus und liefert das Ergebnis, ohne bei Fehlerstatus
    /// zu werfen. Für Aufrufe, bei denen ein Fehlschlag ein erwartetes Ergebnis
    /// ist (Prozess bereits weg, Job existiert nicht).
    @discardableResult
    public static func run(_ path: String, _ args: [String],
                           timeout: TimeInterval = 20) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(path, error)
        }

        // Beide Pipes nebenläufig leeren — sonst blockiert ein Kind, das mehr
        // als die Pipe-Kapazität (64 kB) schreibt, für immer.
        let outData = UnsafeSendableBox(Data())
        let errData = UnsafeSendableBox(Data())
        let group = DispatchGroup()
        for (pipe, box) in [(outPipe, outData), (errPipe, errData)] {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                box.value = pipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
        }

        let deadline = DispatchTime.now() + timeout
        if group.wait(timeout: deadline) == .timedOut {
            process.terminate()
            _ = group.wait(timeout: .now() + 2)
        }
        process.waitUntilExit()

        return ShellResult(
            status: process.terminationStatus,
            stdout: String(data: outData.value, encoding: .utf8) ?? "",
            stderr: String(data: errData.value, encoding: .utf8) ?? ""
        )
    }

    /// Wie `run`, wirft aber bei Fehlerstatus.
    @discardableResult
    public static func check(_ path: String, _ args: [String],
                             timeout: TimeInterval = 20) throws -> String {
        let r = try run(path, args, timeout: timeout)
        guard r.ok else {
            throw ShellError.failed("\(path) \(args.joined(separator: " "))", r.status,
                                    r.stderr.isEmpty ? r.stdout : r.stderr)
        }
        return r.stdout
    }

    /// Läuft der Prozess als root?
    public static var isRoot: Bool { getuid() == 0 }
}

/// Kleiner Box-Typ, um Daten aus den Lese-Threads zurückzugeben.
final class UnsafeSendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
