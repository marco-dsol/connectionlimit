import Foundation
import SQLite3

/// Dünne Hülle um sqlite3. Bewusst minimal — der Store darüber macht die Arbeit.
public final class Database {
    private var handle: OpaquePointer?
    private let queue = DispatchQueue(label: "at.mitsol.connectionlimit.db")

    public enum Error: Swift.Error, LocalizedError {
        case open(String)
        case prepare(String, String)
        case step(String, String)

        public var errorDescription: String? {
            switch self {
            case .open(let m):            return L("Datenbank konnte nicht geöffnet werden: %@", m)
            case .prepare(let sql, let m): return L("SQL-Fehler beim Vorbereiten: %@", m) + "\n\(sql)"
            case .step(let sql, let m):    return L("SQL-Fehler bei der Ausführung: %@", m) + "\n\(sql)"
            }
        }
    }

    public init(path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        var h: OpaquePointer?
        guard sqlite3_open_v2(path, &h,
                              SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
                              nil) == SQLITE_OK, let h else {
            let msg = h.map { String(cString: sqlite3_errmsg($0)) } ?? "unbekannt"
            sqlite3_close(h)
            throw Error.open(msg)
        }
        handle = h
        // WAL: die GUI liest, während der Agent schreibt.
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("PRAGMA busy_timeout=5000;")
    }

    deinit { if let handle { sqlite3_close(handle) } }

    private var message: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "kein Handle"
    }

    public func exec(_ sql: String) throws {
        try queue.sync {
            var err: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(handle, sql, nil, nil, &err) == SQLITE_OK else {
                let m = err.map { String(cString: $0) } ?? message
                sqlite3_free(err)
                throw Error.step(sql, m)
            }
        }
    }

    public enum Value {
        case int(Int64), double(Double), text(String), null
    }

    /// Führt eine schreibende Anweisung aus.
    public func run(_ sql: String, _ params: [Value] = []) throws {
        try queue.sync {
            let stmt = try prepare(sql, params)
            defer { sqlite3_finalize(stmt) }
            let rc = sqlite3_step(stmt)
            guard rc == SQLITE_DONE || rc == SQLITE_ROW else {
                throw Error.step(sql, message)
            }
        }
    }

    /// Führt eine Abfrage aus und bildet jede Zeile ab.
    public func query<T>(_ sql: String, _ params: [Value] = [],
                         _ map: (Row) -> T) throws -> [T] {
        try queue.sync {
            let stmt = try prepare(sql, params)
            defer { sqlite3_finalize(stmt) }
            var out: [T] = []
            while true {
                let rc = sqlite3_step(stmt)
                if rc == SQLITE_ROW { out.append(map(Row(stmt: stmt))) }
                else if rc == SQLITE_DONE { break }
                else { throw Error.step(sql, message) }
            }
            return out
        }
    }

    /// Mehrere Anweisungen als eine Transaktion — für das Sampling wichtig,
    /// sonst kostet jeder Delta-Insert einen eigenen fsync.
    public func transaction(_ body: () throws -> Void) throws {
        try exec("BEGIN IMMEDIATE;")
        do {
            try body()
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    private func prepare(_ sql: String, _ params: [Value]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw Error.prepare(sql, message)
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            switch p {
            case .int(let v):    sqlite3_bind_int64(stmt, idx, v)
            case .double(let v): sqlite3_bind_double(stmt, idx, v)
            case .text(let v):   sqlite3_bind_text(stmt, idx, v, -1, transient)
            case .null:          sqlite3_bind_null(stmt, idx)
            }
        }
        return stmt
    }

    public struct Row {
        let stmt: OpaquePointer?
        public func int(_ i: Int32) -> Int64 { sqlite3_column_int64(stmt, i) }
        public func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
        public func text(_ i: Int32) -> String {
            guard let c = sqlite3_column_text(stmt, i) else { return "" }
            return String(cString: c)
        }
        public func textOrNil(_ i: Int32) -> String? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : text(i)
        }
        public func intOrNil(_ i: Int32) -> Int64? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : int(i)
        }
    }
}
