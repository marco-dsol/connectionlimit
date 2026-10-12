import SwiftUI
import ConnLimitCore

/// Der Inhalt der Menüleiste. Alles, was im Urlaub schnell gehen muss, ist
/// hier erreichbar — alles andere im Fenster.
struct MenuView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    /// So viele Dienste passen ins Menü, ohne dass es zur Tabelle wird.
    private let visibleServices = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if let hint = model.callToAction {
                callout(hint)
                Divider()
            }

            tierPicker
            Divider()

            if let status = model.budgetStatus {
                budgetRow(status)
                Divider()
            }

            serviceSection
            blockedSection
            grantSection

            Divider()
            footer
        }
        .frame(width: 360)
        .padding(.vertical, 6)
    }

    // MARK: - Kopf

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: model.networkClass.symbol)
                        .foregroundStyle(model.networkClass.tint)
                    Text(model.network.displayLabel).fontWeight(.medium).lineLimit(1)
                }
                HStack(spacing: 5) {
                    if model.currentRate > 0 { LivePulse() }
                    Text(L("Heute %@", ByteFormat.short(model.todayTotal)))
                    Text("·")
                    Text(model.currentRate > 0
                         ? ByteFormat.rate(model.currentRate)
                         : L("gerade still"))
                        .foregroundStyle(model.currentRate > 0 ? Palette.active : Color.secondary)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(NetworkClass.allCases, id: \.self) { cls in
                    Button {
                        model.setNetworkClass(cls)
                    } label: {
                        Label(cls.displayName, systemImage:
                                cls == model.networkClass ? "checkmark" : cls.symbol)
                    }
                }
            } label: {
                Text(model.networkClass.displayName)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(model.networkClass.tint)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(model.networkClass.explanation)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func callout(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.leak)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
    }

    // MARK: - Profil

    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                SectionLabel(text: L("Profil"))
                Spacer()
                if model.policyState.isCustomized(model.tier) {
                    Pill(text: L("angepasst"), tint: .secondary, symbol: "pencil")
                }
                if model.isManualTier {
                    // Von Hand gewählt — dann muss der Weg zurück sichtbar
                    // sein. Sonst gälte ein einmal gewähltes „Aus" auch am
                    // nächsten Hotspot noch.
                    Button {
                        model.followNetwork()
                    } label: {
                        Pill(text: L("von Hand"), tint: .orange, symbol: "hand.raised.fill")
                    }
                    .buttonStyle(.plain)
                    .help(L("Zurück zur Automatik: Die Stufe folgt wieder dem Netz (%@).",
                            model.networkTier.displayName))
                } else if model.networkClass != .unknown {
                    Pill(text: L("automatisch"), tint: .secondary, symbol: "wand.and.stars")
                        .help(L("Die Stufe folgt der Einstufung des Netzes."))
                }
            }

            Picker("", selection: Binding(
                get: { model.tier },
                set: { model.setTier($0) })) {
                    ForEach(PolicyTier.allCases, id: \.self) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

            Text(model.tierSummary).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.networkClass == .free,
               let manual = model.policyState.manualTier, manual != .off {
                // In freien Netzen greift bewusst keine Stufe. Ohne diesen
                // Satz sähe es aus, als sei die Auswahl verloren gegangen.
                Text(L("Freies Netz: Hier wird nie gesperrt. „%@“ gilt ab dem nächsten teuren Netz.",
                       manual.displayName))
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: - Budget

    private func budgetRow(_ status: BudgetStatus) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                SectionLabel(text: L("Budget"))
                Spacer()
                Text(L("%@ übrig", ByteFormat.short(status.remainingBytes)))
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(status.light.tint)
            }
            UsageBar(fraction: 1 - status.remainingFraction, tint: status.light.tint)
            Text(L("Heute %@ von %@ · noch %@", ByteFormat.short(status.usedTodayBytes),
                   ByteFormat.short(status.dailyAllowance),
                   relativeRemaining(status.budget.endsAt)))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: - Dienste

    /// Die Dauerliste, gekürzt: gerade Aktive zuerst, dann die größten Posten.
    /// Ein Dienst verschwindet hier nicht, nur weil er kurz still ist — sonst
    /// könnte man genau das nicht sperren, was man gerade sperren will.
    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SectionLabel(text: L("Dienste"))
                Spacer()
                if model.activeCount > 0 {
                    Text(L("%@ aktiv", model.activeCount))
                        .font(.caption2).foregroundStyle(Palette.active)
                }
            }
            .padding(.horizontal, 14).padding(.top, 8)

            if model.tracked.isEmpty {
                Text(L("Noch nichts gesehen — die Messung läuft."))
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.bottom, 8)
            } else {
                let rows = Array(model.tracked.prefix(visibleServices))
                let peak = max(1, rows.map(\.total).max() ?? 1)
                ForEach(rows) { usage in
                    ServiceRow(usage: usage, fraction: Double(usage.total) / Double(peak),
                               model: model)
                }
                if model.tracked.count > rows.count {
                    Button {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        Text(L("… und %@ weitere", model.tracked.count - rows.count))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.top, 2)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Gesperrt

    @ViewBuilder private var blockedSection: some View {
        if !model.blocked.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: L("Gesperrt (%@)", model.blocked.count))
                    .padding(.horizontal, 14).padding(.top, 8)

                ForEach(model.blocked) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").font(.caption2)
                            .foregroundStyle(Palette.blocked)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).font(.callout)
                            Text(subtitle(for: item)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L("Frei")) { model.unblock(item.id) }
                            .buttonStyle(.borderless).font(.caption)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 2)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func subtitle(for item: AppModel.BlockedItem) -> String {
        var parts = [item.reason.displayName]
        if let expires = item.expiresAt {
            parts.append(L("frei in %@", relativeRemaining(expires)))
        }
        if let note = item.lever.bluntnessNote { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var grantSection: some View {
        if !model.grants.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: L("Freigegeben auf Zeit"))
                    .padding(.horizontal, 14).padding(.top, 8)
                ForEach(model.grants) { grant in
                    HStack(spacing: 8) {
                        Image(systemName: "timer").font(.caption2)
                            .foregroundStyle(Palette.active)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(grant.name).font(.callout)
                            Text(L("noch %@ · bisher %@", relativeRemaining(grant.until),
                                   ByteFormat.short(grant.spent)))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 2)
                }
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Fuß

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                model.releaseAll()
            } label: {
                Label(L("Alles freigeben"), systemImage: "lock.open")
            }
            .buttonStyle(.borderless)
            .disabled(model.blocked.isEmpty)

            Spacer()

            LanguageMenu(model: model, compact: true)

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "chart.bar.doc.horizontal")
            }
            .buttonStyle(.borderless)
            .help(L("Fenster öffnen"))

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help(L("Beenden — offene Sperren werden vorher aufgehoben"))
        }
        .padding(.horizontal, 14).padding(.top, 8)
    }
}

/// Eine Zeile in der Dienstliste des Menüs, mit Sperr-/Freigabe-Menü.
struct ServiceRow: View {
    let usage: ServiceUsage
    let fraction: Double
    @ObservedObject var model: AppModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Image(systemName: usage.isBlocked ? "lock.fill" : usage.service.serviceClass.symbol)
                    .font(.caption)
                    .foregroundStyle(usage.tint)
                    .frame(width: 15)
            }
            .overlay(alignment: .topTrailing) {
                if usage.rate > 0 { LivePulse().scaleEffect(0.8).offset(x: 4, y: -2) }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(usage.service.displayName)
                        .font(.callout).lineLimit(1)
                        .foregroundStyle(usage.isActive() ? Palette.active : Color.primary)
                    if usage.isLeaking() {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9)).foregroundStyle(Palette.leak)
                            .help(L("Trotz Sperre sind Daten geflossen"))
                    }
                }
                UsageBar(fraction: fraction, tint: usage.tint)
            }

            Spacer(minLength: 4)

            if hovering {
                actionMenu
            } else {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(ByteFormat.short(usage.total))
                        .font(.caption).monospacedDigit()
                        .foregroundStyle(.secondary)
                    if usage.rate > 0 {
                        Text(ByteFormat.rate(usage.rate))
                            .font(.system(size: 9)).monospacedDigit()
                            .foregroundStyle(Palette.active)
                    } else if let last = usage.lastSeen {
                        Text(relativeAgo(last))
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    @ViewBuilder private var actionMenu: some View {
        if usage.service.isBlockable {
            Menu {
                if usage.isBlocked {
                    Button(L("Freigeben")) { model.unblock(usage.service.id) }
                    Divider()
                    Button(L("15 Minuten freigeben")) { model.grant(usage.service, for: 900) }
                    Button(L("1 Stunde freigeben")) { model.grant(usage.service, for: 3600) }
                } else {
                    Button(L("Jetzt sperren")) { model.block(usage.service) }
                    Divider()
                    Button(L("30 Minuten sperren")) { model.block(usage.service, for: 1800) }
                    Button(L("2 Stunden sperren")) { model.block(usage.service, for: 7200) }
                }
                Divider()
                Button(L("Aus der Liste entfernen")) { model.resetTracking(usage.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        } else {
            Image(systemName: "lock.shield").font(.caption).foregroundStyle(.tertiary)
                .help(L("Systemkritisch — bewusst nicht sperrbar"))
        }
    }
}
