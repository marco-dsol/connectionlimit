import Foundation

/// Winziger Prüf-Rahmen. XCTest und swift-testing setzen ein vollständiges
/// Xcode voraus; hier sind nur die Command Line Tools installiert.
final class Harness {
    private var failures: [String] = []
    private var checks = 0
    private var currentSuite = ""

    func suite(_ name: String, _ body: () throws -> Void) {
        currentSuite = name
        print("\u{1B}[1m\(name)\u{1B}[0m")
        do { try body() }
        catch { record("warf unerwartet: \(error)") }
        print()
    }

    func expect(_ condition: Bool, _ description: String) {
        checks += 1
        if condition {
            print("  \u{1B}[32m✓\u{1B}[0m \(description)")
        } else {
            print("  \u{1B}[31m✗\u{1B}[0m \(description)")
            record(description)
        }
    }

    func expectEqual<T: Equatable>(_ a: T, _ b: T, _ description: String) {
        expect(a == b, a == b ? description : "\(description) — war \(a), erwartet \(b)")
    }

    private func record(_ what: String) {
        failures.append("\(currentSuite): \(what)")
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("\u{1B}[32m\(checks) Prüfungen bestanden.\u{1B}[0m")
            exit(0)
        }
        print("\u{1B}[31m\(failures.count) von \(checks) Prüfungen fehlgeschlagen:\u{1B}[0m")
        for f in failures { print("  · \(f)") }
        exit(1)
    }
}
