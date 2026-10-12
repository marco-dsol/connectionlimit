import SwiftUI
import AppKit
import ConnLimitCore

@main
struct ConnectionLimitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = Launcher.makeModel()

    var body: some Scene {
        MenuBarExtra {
            if Launcher.startupError == nil {
                MenuView(model: model)
                    // Texte entstehen beim Zeichnen; nach einem Sprachwechsel
                    // muss deshalb alles neu gezeichnet werden.
                    .id(model.language)
            } else {
                FailureView(message: Launcher.startupError ?? "")
            }
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("ConnectionLimit", id: "main") {
            if Launcher.startupError == nil {
                MainWindow(model: model)
                    .id(model.language)
            } else {
                FailureView(message: Launcher.startupError ?? "")
            }
        }
        .defaultSize(width: 1000, height: 640)
    }
}

extension Notification.Name {
    /// Aus dem AppDelegate ins Fenster: Ein Menüleisten-Programm hat keinen
    /// anderen Weg, sein Fenster zu öffnen — `openWindow` gibt es nur in einer
    /// View, und die Menü-Inhalte leben erst, wenn das Menü offen ist. Das
    /// Label lebt immer.
    static let openMainWindow = Notification.Name("at.mitsol.connectionlimit.openMainWindow")
}

/// Zeigt Zustand und Rate direkt in der Menüleiste — man soll ohne Klick
/// sehen, ob gerade etwas läuft und ob gesperrt wird.
struct MenuBarLabel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            if model.currentRate > 50_000 {
                Text(ByteFormat.rate(model.currentRate)).monospacedDigit()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var symbol: String {
        // Rangfolge wie in der Farbsprache: ein Durchbruch schlägt alles.
        if !model.leaking.isEmpty { return "exclamationmark.triangle.fill" }
        if !model.blocked.isEmpty { return "lock.fill" }
        switch model.networkClass {
        case .metered: return "exclamationmark.triangle"
        case .limited: return "gauge.with.dots.needle.33percent"
        case .free:    return "wifi"
        case .unknown: return "wifi.exclamationmark"
        }
    }
}

struct FailureView: View {
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("ConnectionLimit konnte nicht starten"), systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message).font(.callout).textSelection(.enabled)
            Text(L("Die Datenbank liegt unter %@.", Store.defaultPath))
                .font(.caption).foregroundStyle(.secondary)
            Button(L("Beenden")) { NSApp.terminate(nil) }
        }
        .padding()
        .frame(width: 380)
    }
}

/// Baut das Modell und hält einen eventuellen Startfehler fest, statt in einem
/// Menüleisten-Programm ohne Fenster stumm abzustürzen.
enum Launcher {
    nonisolated(unsafe) static var startupError: String?

    @MainActor
    static func makeModel() -> AppModel {
        do {
            let model = try AppModel()
            model.start()
            return model
        } catch {
            startupError = error.localizedDescription
            // Ein Platzhalter-Modell auf einer temporären Datenbank, damit die
            // Oberfläche überhaupt zeichnen kann und die Meldung sichtbar wird.
            // Nicht gestartet: Es soll nichts messen und nichts sperren.
            let scratch = FileManager.default.temporaryDirectory
                .appendingPathComponent("connlimit-fallback-\(getpid()).db").path
            if let fallback = try? AppModel(storePath: scratch) { return fallback }
            fatalError("ConnectionLimit: \(error.localizedDescription)")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menüleisten-Programm: kein Dock-Symbol.
        NSApp.setActivationPolicy(.accessory)

        guard !handOverToRunningInstance() else { return }

        // `open -a ConnectionLimit --args --window` öffnet direkt das Fenster.
        if CommandLine.arguments.contains("--window") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }
        }
    }

    /// Läuft dieselbe App schon — etwa aus dem Projektordner, während die
    /// installierte Fassung startet —, übernimmt die ältere Instanz und diese
    /// beendet sich.
    ///
    /// macOS verhindert zwei Instanzen nur bei gleichem Pfad. Zwei Kopien
    /// derselben App messen aber in dieselbe Datenbank: Jeder Messwert stünde
    /// doppelt darin, und der Verbrauch wäre schlicht falsch.
    private func handOverToRunningInstance() -> Bool {
        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == Store.appId
                && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        guard let other = others.first else { return false }
        other.activate()
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
        NSApp.terminate(nil)
        return true
    }

    /// Erneutes Öffnen der App (Finder, Dock, `open`) zeigt das Fenster —
    /// sonst passiert scheinbar nichts, weil es kein Dock-Symbol gibt.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
        // Ohne diesen Schritt bleibt das Fenster im Hintergrund und wird grau
        // gezeichnet — ein Programm ohne Dock-Symbol holt sich den Fokus sonst
        // von nirgendwo.
        sender.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            sender.windows.first { $0.isVisible && $0.level == .normal }?
                .makeKeyAndOrderFront(nil)
        }
        return true
    }

    /// Beim Beenden werden Profil-Sperren aufgehoben. Eine App, die im
    /// Hintergrund eingefrorene Prozesse zurücklässt, wäre nicht vertretbar.
    func applicationWillTerminate(_ notification: Notification) {
        guard let store = try? Store() else { return }
        let catalog = ServiceCatalog.load(userFile: Store.catalogPath)
        let coordinator = EnforcementCoordinator(store: store, catalog: catalog)
        for receipt in (try? store.openReceipts()) ?? [] where receipt.reason != .manual {
            try? coordinator.revert(receipt)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
