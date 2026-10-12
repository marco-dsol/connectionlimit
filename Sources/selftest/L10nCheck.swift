import Foundation
import ConnLimitCore

/// Prüft die Übersetzung: Platzhalter, Rückfall, sprachneutral gespeicherte
/// Angaben. Eine Übersetzung mit einem Platzhalter zu wenig stürzt nicht ab —
/// sie zeigt still die falsche Zahl. Genau das soll hier auffallen.
func checkLocalization(_ t: Harness) {
    t.suite("Übersetzung") {
        let previous = L10n.language
        defer { L10n.language = previous }

        // Platzhalter je Eintrag: dieselben, in derselben Anzahl. Positionale
        // (`%1$@`) zählen wie ihr einfacher Gegenpart.
        func placeholders(_ text: String) -> [String] {
            let regex = try! NSRegularExpression(pattern: "%(\\d+\\$)?@")
            let range = NSRange(text.startIndex..., in: text)
            return regex.matches(in: text, range: range).map { _ in "%@" }
        }
        let broken = L10n.englishTable.filter { placeholders($0.key) != placeholders($0.value) }
        t.expect(broken.isEmpty, "jede Übersetzung hat dieselben Platzhalter"
                 + (broken.isEmpty ? "" : " (abweichend: \(broken.keys.sorted().prefix(5).joined(separator: " | ")))"))

        let stray = L10n.englishTable.filter { $0.key.contains("%d") || $0.value.contains("%d") }
        t.expect(stray.isEmpty, "keine %d-Platzhalter — Zahlen laufen als Text")

        L10n.language = .de
        t.expectEqual(L("Heute %@", "1.0 MB"), "Heute 1.0 MB", "Deutsch ist die Ausgangssprache")
        t.expectEqual(NetworkClass.metered.displayName, "teuer", "deutscher Klassenname")

        L10n.language = .en
        t.expectEqual(L("Heute %@", "1.0 MB"), "Today 1.0 MB", "Englisch füllt den Platzhalter")
        t.expectEqual(L("%@ und %@ weitere", "A, B", 2), "A, B and 2 more", "zwei Platzhalter in Folge")
        t.expectEqual(NetworkClass.metered.displayName, "metered", "Begriff wie auf der Website")
        t.expectEqual(PolicyTier.vacation.displayName, "Vacation", "Stufe übersetzt")
        t.expectEqual(L("Ein Text, den es nicht gibt"), "Ein Text, den es nicht gibt",
                      "fehlende Übersetzung fällt auf den Ausgangstext zurück")

        // Katalog: übersetzte Namen, Markennamen bleiben.
        let catalog = ServiceCatalog.builtin()
        t.expectEqual(catalog.service(id: "icloud-photos")?.displayName, "iCloud Photos",
                      "Dienstname übersetzt")
        t.expectEqual(catalog.service(id: "dropbox")?.displayName, "Dropbox",
                      "Markenname bleibt unverändert")
        t.expectEqual(catalog.service(id: "icloud-photos")?.name, "iCloud Fotos",
                      "gespeicherter Name bleibt die Ausgangsfassung")

        // Protokoll: sprachneutral gespeichert, beim Anzeigen übersetzt.
        let blocked = ServiceEvent(serviceId: "x", kind: .blocked, at: Date(),
                                   detail: "processFreeze · manual")
        t.expectEqual(blocked.displayDetail, "Freeze app · manual", "Hebel und Grund lesbar")
        let legacy = ServiceEvent(serviceId: "x", kind: .released, at: Date(),
                                  detail: "gesperrt seit 25.08. 17:01")
        t.expectEqual(legacy.displayDetail, "gesperrt seit 25.08. 17:01",
                      "Einträge älterer Fassungen bleiben, wie sie sind")
        let since = Date(timeIntervalSince1970: 1_756_134_060)   // 25.08.2025
        let released = ServiceEvent(serviceId: "x", kind: .released, at: Date(),
                                    detail: "since:\(Int64(since.timeIntervalSince1970))")
        t.expect(released.displayDetail?.hasPrefix("blocked since Aug 25") == true,
                 "Freigabe zeigt den Sperrbeginn in der geltenden Sprache")

        // Netznamen: automatisch vergebene folgen der Sprache, eigene nicht.
        let auto = NetworkIdentity(id: "n", interface: "en0", linkType: .wifi,
                                   gatewayIP: "192.168.1.1", gatewayMAC: nil,
                                   label: "WLAN (192.168.1.1)")
        t.expectEqual(auto.displayLabel, "Wi-Fi (192.168.1.1)", "automatischer Netzname übersetzt")
        var named = auto
        named.label = "Hotel Adler"
        t.expectEqual(named.displayLabel, "Hotel Adler", "eigener Netzname bleibt")

        t.expectEqual(DisplayTime.ago(Date().addingTimeInterval(-8 * 60)), "8 min ago",
                      "relative Zeit wie in der Terminal-Demo")
        L10n.language = .de
        t.expectEqual(DisplayTime.ago(Date().addingTimeInterval(-8 * 60)), "vor 8 min",
                      "relative Zeit auf Deutsch")
    }

    t.suite("Eingaben") {
        t.expectEqual(ByteFormat.parse("1,5 GB"), 1_500_000_000, "Komma als Dezimaltrenner")
        t.expect(ByteFormat.parse("-5 GB") == nil, "negative Menge wird abgelehnt")
    }
}

/// Ein Hebel, der nichts tut — um die Quittungslogik ohne echten Eingriff zu
/// prüfen.
private final class InertEnforcer: Enforcer {
    let kind: LeverKind = .processFreeze
    func canEnforce(_ service: Service, spec: LeverSpec, context: EnforcementContext) -> Bool { true }
    func apply(_ service: Service, spec: LeverSpec, receipt: inout EnforcementReceipt,
               context: EnforcementContext) throws {}
    func revert(_ receipt: EnforcementReceipt) throws {}
}

/// Prüft, dass eine bewusst gesetzte Sperre nicht als Profil-Sperre
/// weiterläuft — und dass der gemeinsame Takt befristete Sperren aufhebt.
func checkIntentAndSchedule(_ t: Harness) {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("connlimit-intent-\(UUID().uuidString).db")
    defer {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: tmp.path + suffix)
        }
    }
    guard let store = try? Store(path: tmp.path) else {
        t.suite("Absicht einer Sperre") { t.expect(false, "Datenbank ließ sich nicht anlegen") }
        return
    }

    let service = Service(id: "selftest-sync", name: "Testdienst", serviceClass: .sync,
                          match: ServiceMatch(processes: ["gibt-es-nicht"]),
                          levers: [.processFreeze])
    let catalog = ServiceCatalog(services: [service])
    let coordinator = EnforcementCoordinator(store: store, catalog: catalog,
                                             enforcers: [InertEnforcer()])
    let context = EnforcementContext(network: .offline)

    t.suite("Absicht einer Sperre") {
        try coordinator.block(service, context: context, reason: .profile)
        t.expectEqual(try store.openReceipts().first?.reason, .profile, "Profil sperrt")

        try coordinator.block(service, context: context, reason: .manual)
        let receipts = try store.openReceipts()
        t.expectEqual(receipts.count, 1, "keine zweite Sperre")
        t.expectEqual(receipts.first?.reason, .manual,
                      "von Hand gesperrt übernimmt die Profil-Sperre — ein Profilwechsel hebt sie nicht mehr auf")

        try coordinator.block(service, context: context, reason: .profile)
        t.expectEqual(try store.openReceipts().first?.reason, .manual,
                      "das Profil ändert keine bewusst gesetzte Sperre")

        let until = Date().addingTimeInterval(1800)
        try coordinator.block(service, context: context, reason: .timer, until: until)
        let timed = try store.openReceipts().first
        t.expectEqual(timed?.reason, .timer, "befristet gesperrt")
        t.expect(timed?.expiresAt != nil, "mit Ablaufzeit")

        try coordinator.block(service, context: context, reason: .manual)
        t.expect(try store.openReceipts().first?.expiresAt == nil,
                 "„jetzt sperren“ nach einer befristeten Sperre gilt ohne Frist")
        try coordinator.unblock(serviceId: service.id)
    }

    t.suite("Gemeinsamer Takt") {
        // Eine abgelaufene befristete Sperre. Der Hebel „Pause-Befehl" ohne
        // Fortsetzungsbefehl tut beim Aufheben nichts — kein echter Eingriff.
        let expired = EnforcementReceipt(serviceId: service.id, lever: .appPause,
                                         payload: .init(), expiresAt: Date().addingTimeInterval(-5),
                                         reason: .timer)
        try store.save(expired)

        var config = Agent.Config()
        config.timerInterval = 0
        let agent = Agent(store: store, catalog: catalog, config: config)
        let report = agent.tick()
        t.expect(report.liftedTimers.contains(service.displayName),
                 "der Takt hebt abgelaufene Sperren auf — auch in der App, nicht nur in 'connlimit run'")
        t.expect(try store.openReceipts().isEmpty, "keine Quittung bleibt zurück")
        t.expect(report.policy != nil, "der erste Takt gleicht das Profil ab")
        let second = agent.tick()
        t.expect(second.policy == nil, "danach erst wieder nach dem Abgleichsintervall")
    }
}
