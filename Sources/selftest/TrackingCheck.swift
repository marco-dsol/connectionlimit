import Foundation
import ConnLimitCore

/// Prüft die Dauerbeobachtung: Ein Dienst, der einmal Daten gebraucht hat,
/// muss in der Liste stehen bleiben — auch wenn er tagelang still ist. Genau
/// das ist der Unterschied zu `usage(since:)`, und genau daran hängt, ob man
/// etwas sperren kann, das gerade nichts tut.
func checkTracking(_ t: Harness) {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("connlimit-tracking-\(UUID().uuidString).db")
    defer {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: tmp.path + suffix)
        }
    }

    let net = NetworkIdentity(id: "netz1", interface: "en0", linkType: .wifi,
                              gatewayIP: "192.168.1.1", gatewayMAC: "aa:bb", label: "Test")
    let now = Date()

    t.suite("Dauerbeobachtung") {
        guard let store = try? Store(path: tmp.path) else {
            t.expect(false, "Datenbank ließ sich nicht anlegen")
            return
        }

        // Vor drei Tagen aktiv, seitdem still.
        let longAgo = now.addingTimeInterval(-3 * 86400)
        try store.record(deltas: [UsageDelta(serviceId: "dropbox", bytesIn: 900, bytesOut: 100)],
                         at: longAgo, network: net, networkClass: .metered)

        let today = try store.usage(since: Calendar.current.startOfDay(for: now))
        t.expect(today.isEmpty, "der Tagesverbrauch kennt den alten Dienst nicht mehr")

        let tracked = try store.trackedServices()
        t.expectEqual(tracked.count, 1, "die Dauerliste behält ihn trotzdem")
        t.expectEqual(tracked.first?.total, 1000, "Summe stimmt")
        t.expect(!(tracked.first?.isActive(now: now) ?? true),
                 "nach drei Tagen gilt er nicht mehr als gerade aktiv")

        // Nachschlag: Zähler addieren, erste Sichtung bleibt stehen.
        try store.record(deltas: [UsageDelta(serviceId: "dropbox", bytesIn: 500, bytesOut: 0)],
                         at: now, network: net, networkClass: .metered)
        let updated = try store.trackedServices().first
        t.expectEqual(updated?.total, 1500, "neue Messwerte werden aufaddiert")
        t.expectEqual(updated?.firstSeen.timeIntervalSince1970.rounded(.down),
                      longAgo.timeIntervalSince1970.rounded(.down),
                      "die erste Sichtung bleibt die erste Sichtung")
        t.expect(updated?.isActive(now: now) ?? false, "frischer Messwert ⇒ gerade aktiv")

        // Zweiter Dienst, damit der Reset einzeln geprüft werden kann.
        try store.record(deltas: [UsageDelta(serviceId: "onedrive", bytesIn: 10, bytesOut: 10)],
                         at: now, network: net, networkClass: .free)
        t.expectEqual(try store.trackedServices().count, 2, "zweiter Dienst kommt dazu")

        try store.resetTracking(serviceId: "dropbox")
        let afterSingle = try store.trackedServices()
        t.expectEqual(afterSingle.count, 1, "einzelner Reset entfernt genau einen Eintrag")
        t.expectEqual(afterSingle.first?.serviceId, "onedrive", "und zwar den richtigen")
        t.expectEqual(try store.serviceTotal("dropbox"), 1500,
                      "die Messdaten bleiben erhalten — daran hängt das Budget")

        try store.resetTracking()
        t.expect(try store.trackedServices().isEmpty, "der große Reset leert die Liste")

        // Nach dem Reset fängt der Eintrag von vorn an.
        try store.record(deltas: [UsageDelta(serviceId: "dropbox", bytesIn: 7, bytesOut: 3)],
                         at: now, network: net, networkClass: .metered)
        t.expectEqual(try store.trackedService(id: "dropbox")?.total, 10,
                      "nach dem Reset zählt der Dienst wieder bei null")
    }

    t.suite("Protokoll") {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("connlimit-events-\(UUID().uuidString).db")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: path.path + suffix)
            }
        }
        guard let store = try? Store(path: path.path) else {
            t.expect(false, "Datenbank ließ sich nicht anlegen")
            return
        }

        _ = try store.logEvent(.blocked, serviceId: "dropbox", detail: "processFreeze · manual",
                               at: now.addingTimeInterval(-600))

        // Zwei Durchbrüche kurz hintereinander gehören zu einer Episode —
        // sonst stünden bei 2-s-Sampling 1800 Zeilen pro Stunde in der Liste.
        try store.recordAttempt(serviceId: "dropbox", bytes: 400,
                                at: now.addingTimeInterval(-300))
        try store.recordAttempt(serviceId: "dropbox", bytes: 600,
                                at: now.addingTimeInterval(-260))
        let episodes = try store.events(serviceId: "dropbox", kinds: [.attempt])
        t.expectEqual(episodes.count, 1, "aufeinanderfolgende Durchbrüche werden zusammengefasst")
        t.expectEqual(episodes.first?.bytes, 1000, "die Mengen werden addiert")
        t.expectEqual(episodes.first?.at.timeIntervalSince1970.rounded(.down),
                      now.addingTimeInterval(-300).timeIntervalSince1970.rounded(.down),
                      "der Beginn der Episode bleibt der Zeitpunkt")
        t.expect((episodes.first?.until ?? now) > (episodes.first?.at ?? now),
                 "das Ende wird nachgeführt")

        // Nach längerer Ruhe beginnt eine neue Episode.
        try store.recordAttempt(serviceId: "dropbox", bytes: 50, at: now)
        t.expectEqual(try store.events(serviceId: "dropbox", kinds: [.attempt]).count, 2,
                      "nach Ruhe beginnt eine neue Episode")

        let summary = try store.attemptSummary()
        t.expectEqual(summary["dropbox"]?.count, 2, "Verdichtung zählt die Episoden")
        t.expectEqual(summary["dropbox"]?.bytes, 1050, "Verdichtung summiert die Mengen")

        let all = try store.events(limit: 10)
        t.expectEqual(all.count, 3, "das Protokoll enthält auch die Sperre")
        t.expect(all.first?.at ?? .distantPast >= all.last?.at ?? .distantFuture,
                 "jüngster Eintrag zuerst")
    }

    t.suite("Mengenverlauf") {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("connlimit-history-\(UUID().uuidString).db")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: path.path + suffix)
            }
        }
        guard let store = try? Store(path: path.path) else {
            t.expect(false, "Datenbank ließ sich nicht anlegen")
            return
        }

        // Zwei Messwerte, drei Stunden auseinander — dazwischen muss eine
        // echte Lücke stehen, keine übersprungene Stunde.
        try store.record(deltas: [UsageDelta(serviceId: "chrome", bytesIn: 100, bytesOut: 0)],
                         at: now.addingTimeInterval(-3 * 3600), network: net, networkClass: .free)
        try store.record(deltas: [UsageDelta(serviceId: "chrome", bytesIn: 300, bytesOut: 100)],
                         at: now, network: net, networkClass: .free)

        let series = try store.history(serviceId: "chrome",
                                       since: now.addingTimeInterval(-4 * 3600),
                                       until: now, bucket: 3600)
        t.expect(series.count >= 4, "der Verlauf deckt den ganzen Zeitraum ab (\(series.count))")
        t.expectEqual(series.map(\.total).reduce(0, +), 500, "die Summe bleibt erhalten")
        t.expect(series.contains { $0.total == 0 },
                 "stille Fenster stehen als Null da, statt zu fehlen")
        t.expectEqual(series.last?.total, 400, "der jüngste Messwert liegt im letzten Fenster")

        let unknownService = try store.history(serviceId: "gibtsnicht",
                                               since: now.addingTimeInterval(-3600), until: now)
        t.expect(unknownService.isEmpty, "ein unbekannter Dienst liefert keinen erfundenen Verlauf")
    }

    t.suite("Editierbare Profile") {
        var state = PolicyState()
        t.expectEqual(state.blockedClasses(for: .frugal), PolicyTier.frugal.defaultBlockedClasses,
                      "ohne Anpassung gilt die Voreinstellung")
        t.expect(!state.isCustomized(.frugal), "unverändert ist nicht angepasst")

        state.setBlockedClasses([.media, .sync], for: .frugal)
        t.expectEqual(state.blockedClasses(for: .frugal), [.media, .sync],
                      "eigene Belegung wird übernommen")
        t.expect(state.isCustomized(.frugal), "Anpassung wird erkannt")

        // Systemkritisches darf sich keiner Stufe zuordnen lassen.
        state.setBlockedClasses([.essential, .media], for: .vacation)
        t.expect(!state.blockedClasses(for: .vacation).contains(.essential),
                 "Systemkritisches lässt sich keiner Stufe zuordnen")

        state.setBlockedClasses([], for: .off)
        t.expect(state.blockedClasses(for: .off).isEmpty, "„Aus“ bleibt aus")

        // Urlaub sperrt jetzt nur Medien, Sparsam Medien und Sync — die höhere
        // Stufe sperrt weniger, und das muss auffallen.
        t.expect(state.inconsistentTiers.contains(.vacation),
                 "eine höhere Stufe, die weniger sperrt, wird gemeldet")

        state.resetTier(.frugal)
        state.resetTier(.vacation)
        t.expect(state.inconsistentTiers.isEmpty,
                 "die Voreinstellung ist in sich stimmig")

        // Der gespeicherte Zustand muss einen Neustart überstehen.
        state.setBlockedClasses([.browser], for: .emergency)
        guard let data = try? JSONEncoder().encode(state),
              let restored = try? JSONDecoder().decode(PolicyState.self, from: data) else {
            t.expect(false, "Profilzustand ließ sich nicht serialisieren")
            return
        }
        t.expectEqual(restored.blockedClasses(for: .emergency), [.browser],
                      "eigene Belegung übersteht einen Neustart")

        // Ältere Datenbanken kennen das Feld nicht — das darf nicht werfen.
        let legacy = #"{"followNetwork":true,"autoEscalate":true,"alwaysAllow":[],"alwaysBlock":[]}"#
        let old = try? JSONDecoder().decode(PolicyState.self, from: Data(legacy.utf8))
        t.expect(old != nil, "ein Profilzustand ohne eigene Belegung lässt sich weiterhin lesen")
        t.expectEqual(old?.blockedClasses(for: .vacation), PolicyTier.vacation.defaultBlockedClasses,
                      "und fällt auf die Voreinstellung zurück")
    }
}

/// Prüft den Selbstschutz: Das Werkzeug darf sich nicht selbst aussperren.
///
/// Wird es aus einem Terminal heraus bedient, ist dieses Terminal ein
/// Vorfahre des Prozesses. Ein eingefrorenes Terminal könnte den Befehl zum
/// Auftauen nicht mehr absetzen — die Sperre wäre endgültig.
func checkSelfProtection(_ t: Harness) {
    t.suite("Selbstschutz") {
        let protected = ProcessLookup.protectedPIDs()
        t.expect(protected.contains(getpid()), "der eigene Prozess ist geschützt")
        t.expect(protected.contains(getppid()), "der Elternprozess ist geschützt")
        t.expect(protected.count >= 2, "die Abstammung wird verfolgt (\(protected.count) Prozesse)")
        t.expect(!protected.contains(1), "launchd selbst steht nicht in der Liste")

        // Ein Dienst, dessen einziger Treffer der eigene Prozess wäre, darf
        // nicht als sperrbar gelten.
        let ownPath = ProcessInfo.processInfo.arguments.first ?? ""
        let ownName = (ownPath as NSString).lastPathComponent
        let selfService = Service(id: "test-selbst", name: "Selbsttest", serviceClass: .other,
                                  match: ServiceMatch(processes: [ownName]),
                                  levers: [.processFreeze])
        let enforcer = ProcessFreezeEnforcer()
        let context = EnforcementContext(network: .offline,
                                         livePIDs: ["test-selbst": [getpid(), getppid()]])
        t.expect(!enforcer.canEnforce(selfService, spec: .processFreeze, context: context),
                 "ein Hebel, der nur eigene Prozesse träfe, meldet sich als nicht anwendbar")
    }
}
