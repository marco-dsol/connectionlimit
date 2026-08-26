import Foundation
import ConnLimitCore

let t = Harness()

// MARK: - nettop-Ausgabe

t.suite("nettop-Ausgabe") {
    let samples = NettopSampler.parse("""
    ,bytes_in,bytes_out,
    apsd.363,557177,610194,
    mDNSResponder.478,201985898,146303314,
    """)
    t.expectEqual(samples.count, 2, "Kopfzeile wird übersprungen")
    t.expectEqual(samples[0].name, "apsd", "Name gelesen")
    t.expectEqual(samples[0].pid, 363, "PID gelesen")
    t.expectEqual(samples[0].bytesIn, 557_177, "bytes_in gelesen")
    t.expectEqual(samples[1].bytesOut, 146_303_314, "bytes_out gelesen")

    // nettop kürzt Namen auf 15 Zeichen; der Name selbst darf Punkte enthalten.
    let tricky = NettopSampler.parse("""
    ,bytes_in,bytes_out,
    Google Chrome H.8241,11742,3437,
    zoom.us.999,10,20,
    """)
    t.expectEqual(tricky.count, 2, "Namen mit Leerzeichen und Punkten")
    t.expectEqual(tricky[0].name, "Google Chrome H", "am letzten Punkt getrennt")
    t.expectEqual(tricky[1].name, "zoom.us", "Punkt im Namen bleibt erhalten")
    t.expectEqual(tricky[1].pid, 999, "PID hinter dem letzten Punkt")

    let garbage = NettopSampler.parse("""
    ,bytes_in,bytes_out,
    kaputt-ohne-pid,1,2,
    ohnepid.,3,4,
    gut.42,5,6,
    """)
    t.expectEqual(garbage.count, 1, "kaputte Zeilen werden übersprungen, nicht geworfen")
}

// MARK: - Zuwachsberechnung

t.suite("Zuwachsberechnung") {
    let acc = DeltaAccumulator()
    let first = acc.ingest([ProcessSample(name: "a", pid: 1, bytesIn: 1000, bytesOut: 500)])
    t.expect(first.deltas.isEmpty,
             "erstes Sample setzt nur die Basislinie — der Altbestand ist kein Zuwachs")

    let second = acc.ingest([ProcessSample(name: "a", pid: 1, bytesIn: 1500, bytesOut: 800)])
    t.expectEqual(second.deltas.count, 1, "zweites Sample liefert einen Zuwachs")
    t.expectEqual(second.deltas[0].bytesIn, 500, "Differenz eingehend")
    t.expectEqual(second.deltas[0].bytesOut, 300, "Differenz ausgehend")

    // Prozess neu gestartet, PID wiederverwendet: Zähler springt zurück.
    let reset = acc.ingest([ProcessSample(name: "a", pid: 1, bytesIn: 5, bytesOut: 0)])
    t.expect(reset.deltas.isEmpty, "Zählerrücksetzer wird verworfen statt negativ verbucht")

    let acc2 = DeltaAccumulator()
    _ = acc2.ingest([ProcessSample(name: "b", pid: 7, bytesIn: 100, bytesOut: 0)])
    _ = acc2.ingest([])
    let ghost = acc2.ingest([ProcessSample(name: "b", pid: 7, bytesIn: 100, bytesOut: 0)])
    t.expect(ghost.deltas.isEmpty, "verschwundene PID hinterlässt keinen Geisterzuwachs")
    t.expectEqual(ghost.livePIDs, Set<Int32>([7]), "lebende PIDs werden gemeldet")
}

// MARK: - Datenmengen

t.suite("Datenmengen") {
    // Mobilfunktarife rechnen dezimal ab — deshalb 1 kB = 1000 B, nicht 1024.
    t.expectEqual(ByteFormat.short(999), "999 B", "Bytes")
    t.expectEqual(ByteFormat.short(1_500), "1.5 kB", "Kilobyte dezimal")
    t.expectEqual(ByteFormat.short(5_000_000_000), "5.00 GB", "Gigabyte dezimal")
    t.expectEqual(ByteFormat.parse("5GB"), 5_000_000_000, "Eingabe 5GB")
    t.expectEqual(ByteFormat.parse("500 MB"), 500_000_000, "Eingabe mit Leerzeichen")
    t.expectEqual(ByteFormat.parse("1.5gb"), 1_500_000_000, "Eingabe mit Komma-Wert")
    t.expect(ByteFormat.parse("quatsch") == nil, "unlesbare Eingabe ergibt nil")
}

// MARK: - Dienstzuordnung

t.suite("Dienstzuordnung") {
    let catalog = ServiceCatalog.builtin()

    t.expectEqual(catalog.resolve(processName: "bird", info: nil).id, "icloud-drive",
                  "Daemon über exakten Namen")
    t.expectEqual(catalog.resolve(processName: "softwareupdated", info: nil).id, "macos-update",
                  "Update-Daemon erkannt")

    // "Microsoft Outlook" ist 17 Zeichen lang, nettop liefert 15.
    t.expectEqual(catalog.resolve(processName: "Microsoft Outlo", info: nil).id, "outlook",
                  "gekürzter Name findet trotzdem den Dienst")

    let dropboxInfo = ProcessResolver.Info(
        pid: 1, executablePath: "/Applications/Irgendwas.app/Contents/MacOS/Irgendwas",
        bundleId: "com.getdropbox.dropbox", startedAt: "")
    t.expectEqual(catalog.resolve(processName: "Irgendwas", info: dropboxInfo).id, "dropbox",
                  "Bundle-ID schlägt den Prozessnamen")

    let brewInfo = ProcessResolver.Info(
        pid: 1, executablePath: "/opt/homebrew/bin/etwas", bundleId: nil, startedAt: "")
    t.expectEqual(catalog.resolve(processName: "etwas", info: brewInfo).id, "homebrew",
                  "Pfad-Präfix erkennt Homebrew")

    let unknown = catalog.resolve(processName: "voellig-neues-ding", info: nil)
    t.expect(unknown.isUnknown, "unbekannte Prozesse verschwinden nicht")
    t.expectEqual(unknown.name, "voellig-neues-ding", "unbekannter Dienst behält seinen Namen")

    let ids = catalog.services.map(\.id)
    t.expectEqual(Set(ids).count, ids.count, "jede Dienst-ID kommt nur einmal vor")

    var missingLever: [String] = []
    for s in catalog.services
    where s.serviceClass != .essential && s.serviceClass != .messaging && s.levers.isEmpty {
        missingLever.append(s.id)
    }
    t.expect(missingLever.isEmpty,
             "jeder sperrbare Dienst hat einen Hebel" +
             (missingLever.isEmpty ? "" : " (fehlt bei: \(missingLever.joined(separator: ", ")))"))
}

// MARK: - Schutz systemkritischer Dienste

t.suite("Schutz systemkritischer Dienste") {
    let catalog = ServiceCatalog.builtin()
    for id in ["dns", "vpn", "apple-push", "connectionlimit", "security", "network-stack"] {
        guard let service = catalog.service(id: id) else {
            t.expect(false, "Dienst \(id) fehlt im Katalog")
            continue
        }
        t.expect(!service.isBlockable, "\(service.name) ist gegen jede Sperre geschützt")
    }
    for tier in PolicyTier.allCases {
        t.expect(!tier.defaultBlockedClasses.contains(.essential),
                 "Stufe \(tier.displayName) sperrt nichts Systemkritisches")
    }
}

// MARK: - Eskalationsstufen

t.suite("Eskalationsstufen") {
    t.expect(PolicyTier.frugal.defaultBlockedClasses.isSubset(of: PolicyTier.vacation.defaultBlockedClasses),
             "Urlaubsmodus enthält alles aus Sparsam")
    t.expect(PolicyTier.vacation.defaultBlockedClasses.isSubset(of: PolicyTier.emergency.defaultBlockedClasses),
             "Notfall enthält alles aus Urlaubsmodus")
    t.expect(PolicyTier.frugal.defaultBlockedClasses.contains(.update),
             "Sparsam sperrt Updates")
    t.expect(!PolicyTier.frugal.defaultBlockedClasses.contains(.sync),
             "Sparsam lässt Cloud-Sync laufen")
    t.expect(PolicyTier.vacation.defaultBlockedClasses.contains(.sync),
             "Urlaubsmodus sperrt Cloud-Sync")
    t.expect(!PolicyTier.vacation.defaultBlockedClasses.contains(.messaging),
             "Urlaubsmodus lässt Messenger laufen")
}

// MARK: - Netzklassen

t.suite("Netzklassen") {
    t.expectEqual(NetworkClass.unknown.defaultTier, .off,
                  "unbekanntes Netz sperrt nichts, bis der Nutzer es einstuft")
    t.expectEqual(NetworkClass.free.defaultTier, .off, "freies Netz sperrt nichts")
    t.expectEqual(NetworkClass.metered.defaultTier, .vacation,
                  "teures Netz aktiviert den Urlaubsmodus")
    t.expect(!NetworkClass.free.countsAgainstBudget, "freies Netz zählt nicht aufs Budget")
    t.expect(NetworkClass.metered.countsAgainstBudget, "teures Netz zählt aufs Budget")

    let identifier = NetworkIdentifier()
    t.expect(identifier.isIOSHotspot(gateway: "172.20.10.1"),
             "iPhone-Hotspot wird am Gateway erkannt")
    t.expect(!identifier.isIOSHotspot(gateway: "192.168.1.1"),
             "normales Heimnetz ist kein Hotspot")
}

// MARK: - Budget

t.suite("Budgetrechnung") {
    let start = Date().addingTimeInterval(-2 * 86_400)
    let end = Date().addingTimeInterval(8 * 86_400)
    let budget = Budget(totalBytes: 5_000_000_000, startsAt: start, endsAt: end)

    let healthy = BudgetStatus(budget: budget, usedBytes: 1_000_000_000, usedTodayBytes: 0)
    t.expectEqual(healthy.remainingBytes, 4_000_000_000, "Restvolumen")
    t.expect(healthy.dailyAllowance > 400_000_000 && healthy.dailyAllowance < 600_000_000,
             "Tagesbudget verteilt den Rest auf die Resttage")
    t.expectEqual(healthy.light, .green, "ohne Verbrauch heute ist die Ampel grün")

    let overspent = BudgetStatus(budget: budget, usedBytes: 4_900_000_000,
                                 usedTodayBytes: 100_000_000)
    t.expect(overspent.remainingFraction < 0.05, "Restanteil unter 5 %")

    // Ein Budget ohne Restvolumen darf nicht durch Null teilen.
    let empty = BudgetStatus(
        budget: Budget(totalBytes: 0, startsAt: start, endsAt: end),
        usedBytes: 0, usedTodayBytes: 0)
    t.expectEqual(empty.light, .red, "leeres Budget ist rot statt Absturz")
    t.expectEqual(empty.remainingFraction, 0, "leeres Budget hat 0 % Rest")
}

// MARK: - Quittungen

t.suite("Quittungen") {
    let expired = EnforcementReceipt(
        serviceId: "dropbox", lever: .processFreeze, payload: .init(pids: [1]),
        expiresAt: Date().addingTimeInterval(-60))
    t.expect(expired.isExpired, "abgelaufene Sperre wird als abgelaufen erkannt")

    let openEnded = EnforcementReceipt(
        serviceId: "dropbox", lever: .processFreeze, payload: .init(pids: [1]))
    t.expect(!openEnded.isExpired, "Sperre ohne Frist läuft nicht von selbst ab")

    // Quittungen müssen einen Neustart überstehen.
    let original = EnforcementReceipt(
        serviceId: "onedrive", lever: .launchdFreeze,
        payload: .init(pids: [42, 43], jobs: ["com.apple.bird"], anchorRule: "a/b"),
        reason: .profile)
    guard let data = try? JSONEncoder().encode(original),
          let restored = try? JSONDecoder().decode(EnforcementReceipt.self, from: data) else {
        t.expect(false, "Quittung ließ sich nicht serialisieren")
        return
    }
    t.expectEqual(restored.payload.pids, [42, 43], "PIDs überstehen einen Neustart")
    t.expectEqual(restored.payload.jobs, ["com.apple.bird"], "launchd-Jobs überstehen einen Neustart")
    t.expectEqual(restored.reason, .profile, "Grund der Sperre bleibt erhalten")
}

// MARK: - Datenbank

t.suite("Datenbank") {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("connlimit-selftest-\(UUID().uuidString).db")
    defer { try? FileManager.default.removeItem(at: tmp) }

    guard let store = try? Store(path: tmp.path) else {
        t.expect(false, "Datenbank ließ sich nicht anlegen")
        return
    }
    let net = NetworkIdentity(id: "netz1", interface: "en0", linkType: .wifi,
                              gatewayIP: "192.168.1.1", gatewayMAC: "aa:bb", label: "Test")

    try store.record(deltas: [UsageDelta(serviceId: "dropbox", bytesIn: 1000, bytesOut: 500)],
                     at: Date(), network: net, networkClass: .metered)
    try store.record(deltas: [UsageDelta(serviceId: "dropbox", bytesIn: 200, bytesOut: 100)],
                     at: Date(), network: net, networkClass: .free)

    let all = try store.usage(since: Date().addingTimeInterval(-60))
    t.expectEqual(all.first?.total, 1800, "Verbrauch wird summiert")

    let metered = try store.usage(since: Date().addingTimeInterval(-60),
                                  networkClasses: [.metered])
    t.expectEqual(metered.first?.total, 1500, "Filter auf teure Netze greift")
    t.expectEqual(try store.serviceTotal("dropbox"), 1800, "Einzelabfrage stimmt mit Summe überein")

    try store.upsertNetwork(net, class: .metered)
    t.expectEqual(try store.networkClass(for: "netz1"), .metered, "Netzklasse wird gespeichert")
    try store.setNetworkClass(.free, for: "netz1")
    t.expectEqual(try store.networkClass(for: "netz1"), .free, "Netzklasse lässt sich ändern")

    var state = PolicyState()
    state.manualTier = .vacation
    state.alwaysAllow = ["nextcloud"]
    try store.savePolicyState(state)
    t.expectEqual(store.policyState.manualTier, .vacation, "Profil überlebt in der Datenbank")
    t.expect(store.policyState.alwaysAllow.contains("nextcloud"), "Ausnahmen bleiben erhalten")

    let receipt = EnforcementReceipt(serviceId: "dropbox", lever: .processFreeze,
                                     payload: .init(pids: [99]))
    try store.save(receipt)
    t.expectEqual(try store.openReceipts().count, 1, "Quittung wird gespeichert")
    try store.deleteReceipt(id: receipt.id)
    t.expectEqual(try store.openReceipts().count, 0, "Quittung wird gelöscht")
}

// MARK: - Prozesssuche

t.suite("Prozesssuche") {
    let running = ProcessLookup.running()
    t.expect(running.count > 10, "laufende Prozesse werden gefunden (\(running.count))")
    t.expect(ProcessLookup.isAlive(getpid()), "der eigene Prozess lebt")
    t.expect(!ProcessLookup.isAlive(999_999), "eine erfundene PID lebt nicht")

    // Die Suche muss eng sein: ein Dienst namens "Mail" darf nicht halbe
    // Systemprozesse einfrieren, nur weil deren Pfad "mail" enthält.
    let narrow = Service(id: "test", name: "Test", serviceClass: .sync,
                         match: ServiceMatch(processes: ["ein-prozess-den-es-nicht-gibt"]))
    t.expect(ProcessLookup.pids(for: narrow, in: running).isEmpty,
             "kein Treffer bei erfundenem Prozessnamen")
}

checkTracking(t)
checkSelfProtection(t)
checkEnforcementRoundTrip(t)

t.finish()
