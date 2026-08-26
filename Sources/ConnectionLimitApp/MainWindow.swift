import SwiftUI
import ConnLimitCore

struct MainWindow: View {
    @ObservedObject var model: AppModel
    /// Merkt sich den zuletzt geöffneten Bereich. Wer das Fenster wegen einer
    /// bestimmten Sache öffnet, öffnet es meist wieder wegen derselben.
    @AppStorage("mainTab") private var storedTab: String = Tab.usage.rawValue

    private var tab: Binding<Tab> {
        Binding(get: { Tab(rawValue: storedTab) ?? .usage },
                set: { storedTab = $0.rawValue })
    }

    enum Tab: String, CaseIterable, Identifiable {
        case usage = "Verbrauch"
        case log = "Protokoll"
        case profiles = "Profile"
        case services = "Dienste"
        case networks = "Netze"
        case budget = "Budget"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .usage:    return "chart.bar.xaxis"
            case .log:      return "list.bullet.rectangle"
            case .profiles: return "slider.horizontal.3"
            case .services: return "square.grid.2x2"
            case .networks: return "wifi"
            case .budget:   return "gauge.with.needle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: tab) {
                Section("Sehen") {
                    row(.usage); row(.log)
                }
                Section("Begrenzen") {
                    row(.profiles); row(.services); row(.budget)
                }
                Section("Einrichten") {
                    row(.networks)
                }
            }
            .navigationSplitViewColumnWidth(min: 168, ideal: 184, max: 220)
            .safeAreaInset(edge: .bottom) { sidebarFooter }
        } detail: {
            Group {
                switch tab.wrappedValue {
                case .usage:    UsageView(model: model)
                case .log:      LogView(model: model)
                case .profiles: ProfilesView(model: model)
                case .services: ServicesView(model: model)
                case .networks: NetworksView(model: model)
                case .budget:   BudgetView(model: model)
                }
            }
            .frame(minWidth: 640, minHeight: 460)
        }
        .navigationTitle("ConnectionLimit")
    }

    private func row(_ item: Tab) -> some View {
        Label(item.rawValue, systemImage: item.symbol).tag(item)
    }

    /// Zustand auf einen Blick, ohne die Menüleiste zu öffnen.
    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack(spacing: 6) {
                Image(systemName: model.networkClass.symbol)
                    .foregroundStyle(model.networkClass.tint)
                Text(model.network.label).lineLimit(1).font(.caption)
            }
            HStack(spacing: 6) {
                if model.currentRate > 0 { LivePulse() } else {
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 7, height: 7)
                }
                Text(model.currentRate > 0 ? ByteFormat.rate(model.currentRate) : "still")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Pill(text: model.tier.displayName, tint: model.tier.tint,
                     symbol: model.tier.symbol)
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 10)
    }
}

// MARK: - Verbrauch

struct UsageView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var detail: DetailTarget?
    @State private var confirmReset = false

    struct DetailTarget: Identifiable { let id: String }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case active = "Aktiv"
        case blocked = "Gesperrt"
        case leaking = "Durchbrüche"
        var id: String { rawValue }
    }

    private var rows: [ServiceUsage] {
        model.tracked.filter { usage in
            let matchesSearch = search.isEmpty
                || usage.service.name.localizedCaseInsensitiveContains(search)
            guard matchesSearch else { return false }
            switch filter {
            case .all:      return true
            case .active:   return usage.isActive()
            case .blocked:  return usage.isBlocked
            case .leaking:  return usage.attemptCount > 0
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            toolbar
            Divider()

            if model.tracked.isEmpty {
                emptyState
            } else if rows.isEmpty {
                filteredEmptyState
            } else {
                List {
                    ForEach(rows) { usage in
                        TrackedRow(usage: usage,
                                   history: model.history[usage.id] ?? [],
                                   peak: peak,
                                   model: model,
                                   onDetail: { detail = DetailTarget(id: usage.id) })
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(item: $detail) { target in
            ServiceDetailSheet(serviceId: target.id, model: model)
        }
        .confirmationDialog("Zählung für alle Dienste zurücksetzen?",
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Liste leeren", role: .destructive) { model.resetTracking() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Liste beginnt von vorn. Messdaten und Budget bleiben unberührt — "
               + "Dienste erscheinen wieder, sobald sie das nächste Mal Daten brauchen.")
        }
    }

    private var peak: Int64 { max(1, model.tracked.map(\.total).max() ?? 1) }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verbrauch").font(.title2).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: model.networkClass.symbol)
                    Text(model.network.label)
                }
                .font(.callout)
                .foregroundStyle(model.networkClass.tint)
                .help(model.networkClass.explanation)
            }

            HStack(spacing: 10) {
                StatTile(title: "Heute", value: ByteFormat.short(model.todayTotal),
                         note: "seit Mitternacht", symbol: "sun.horizon")
                StatTile(title: "Gerade",
                         value: model.currentRate > 0 ? ByteFormat.rate(model.currentRate) : "—",
                         note: "\(model.activeCount) aktiv",
                         tint: model.currentRate > 0 ? Palette.active : .primary,
                         symbol: "waveform")
                StatTile(title: "Beobachtet", value: "\(model.tracked.count)",
                         note: "Dienste in der Liste", symbol: "eye")
                StatTile(title: "Gesperrt", value: "\(model.blocked.count)",
                         note: model.leaking.isEmpty
                             ? "keine Durchbrüche"
                             : "\(model.leaking.count) mit Durchbruch",
                         tint: model.leaking.isEmpty
                             ? (model.blocked.isEmpty ? .primary : Palette.blocked)
                             : Palette.leak,
                         symbol: "lock")
            }
        }
        .padding(16)
    }

    private var subtitle: String {
        var parts = ["Jeder Dienst bleibt in der Liste, bis du ihn zurücksetzt"]
        if let since = model.trackingSince {
            parts.append("gezählt seit \(dateStamp(since))")
        }
        return parts.joined(separator: " · ")
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Suchen", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(Palette.cardBackground))
            .frame(minWidth: 130, idealWidth: 180, maxWidth: 220)

            Picker("", selection: $filter) {
                ForEach(Filter.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()

            Spacer()

            Button {
                confirmReset = true
            } label: {
                Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.small)
            .disabled(model.tracked.isEmpty)
            .help("Leert die Liste. Messdaten und Budget bleiben erhalten.")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "chart.bar.xaxis").font(.largeTitle).foregroundStyle(.tertiary)
            Text("Noch nichts gesehen").font(.headline)
            Text("Die Messung läuft, solange diese App geöffnet ist. Wer Daten braucht, "
               + "landet hier — und bleibt stehen, auch wenn er wieder still ist.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Text(filter == .leaking ? "Keine Durchbrüche" : "Kein Treffer")
                .font(.headline).foregroundStyle(.secondary)
            if filter == .leaking {
                Text("Es ist noch nie etwas durch eine gesetzte Sperre gekommen.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Eine Zeile der Dauerliste.
struct TrackedRow: View {
    let usage: ServiceUsage
    let history: [HistoryBucket]
    let peak: Int64
    @ObservedObject var model: AppModel
    var onDetail: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(usage.service.name)
                        .fontWeight(.medium)
                        .foregroundStyle(usage.isActive() ? Palette.active : Color.primary)
                        .lineLimit(1)
                    if usage.isLeaking() {
                        Pill(text: "trotz Sperre", tint: Palette.leak,
                             symbol: "exclamationmark.triangle.fill")
                    } else if usage.isBlocked {
                        Pill(text: "gesperrt", tint: Palette.blocked, symbol: "lock.fill")
                    }
                    if usage.service.isUnknown {
                        Pill(text: "unbekannt", tint: .secondary)
                    }
                }
                UsageBar(fraction: Double(usage.total) / Double(max(1, peak)), tint: usage.tint)
                    .frame(maxWidth: 260)
                Text(caption).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer(minLength: 8)

            Sparkline(buckets: history, tint: usage.tint)
                .frame(width: 78)
                .opacity(history.isEmpty ? 0.3 : 1)

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteFormat.short(usage.total))
                    .monospacedDigit().fontWeight(.semibold)
                Text(usage.isActive() && usage.rate > 0
                     ? ByteFormat.rate(usage.rate)
                     : "heute \(ByteFormat.short(usage.todayBytes))")
                    .font(.caption2).monospacedDigit()
                    .foregroundStyle(usage.rate > 0 ? Palette.active : Color.secondary)
            }
            .frame(width: 92, alignment: .trailing)

            actions
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { onDetail() }
        .contextMenu {
            Button("Details und Verlauf …") { onDetail() }
            Divider()
            if usage.service.isBlockable {
                Button(usage.isBlocked ? "Freigeben" : "Jetzt sperren") { toggleBlock() }
                Button("30 Minuten sperren") { model.block(usage.service, for: 1800) }
                Button("1 Stunde freigeben") { model.grant(usage.service, for: 3600) }
                Divider()
            }
            Button("Aus der Liste entfernen") { model.resetTracking(usage.id) }
        }
    }

    private var statusIcon: some View {
        ZStack {
            Circle().fill(usage.tint.opacity(0.14)).frame(width: 30, height: 30)
            if usage.isActive() && !usage.isBlocked {
                Image(systemName: usage.service.serviceClass.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.active)
            } else {
                Image(systemName: usage.isBlocked
                      ? (usage.isLeaking() ? "exclamationmark.triangle.fill" : "lock.fill")
                      : usage.service.serviceClass.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(usage.tint)
            }
        }
        .overlay(alignment: .topTrailing) {
            if usage.rate > 0 { LivePulse().offset(x: 3, y: -1) }
        }
    }

    private var caption: String {
        var parts = [usage.service.serviceClass.displayName]
        if usage.rate > 0 {
            parts.append("gerade aktiv")
        } else if let last = usage.lastSeen {
            parts.append("zuletzt \(relativeAgo(last))")
        }
        if usage.attemptCount > 0 {
            parts.append("\(usage.attemptCount)× trotz Sperre · \(ByteFormat.short(usage.attemptBytes))")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var actions: some View {
        if usage.service.isBlockable {
            Button(usage.isBlocked ? "Freigeben" : "Sperren") { toggleBlock() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(usage.isBlocked ? Palette.active : Palette.blocked)
        } else {
            Image(systemName: "lock.shield").foregroundStyle(.tertiary)
                .help("Systemkritisch — bewusst nicht sperrbar")
                .frame(width: 62)
        }
    }

    private func toggleBlock() {
        if usage.isBlocked { model.unblock(usage.service.id) }
        else { model.block(usage.service) }
    }
}

// MARK: - Detail

struct ServiceDetailSheet: View {
    let serviceId: String
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var range = Range24

    static let Range24 = 24
    private var usage: ServiceUsage? { model.tracked.first { $0.id == serviceId } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    numbers
                    chart
                    protocolCard
                    leverCard
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 620)
    }

    private var service: Service {
        usage?.service ?? model.catalog.serviceOrUnknown(id: serviceId)
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill((usage?.tint ?? .secondary).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: service.serviceClass.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(usage?.tint ?? .secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(service.name).font(.title3).fontWeight(.semibold)
                HStack(spacing: 6) {
                    Text(service.serviceClass.displayName)
                        .font(.caption).foregroundStyle(.secondary)
                    if let usage {
                        Pill(text: usage.statusText, tint: usage.tint, symbol: usage.statusSymbol)
                    }
                }
            }
            Spacer()
            Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var numbers: some View {
        HStack(spacing: 10) {
            StatTile(title: "Gesamt", value: ByteFormat.short(usage?.total ?? 0),
                     note: usage?.firstSeen.map { "seit \(dateStamp($0))" } ?? "—")
            StatTile(title: "Heute", value: ByteFormat.short(usage?.todayBytes ?? 0),
                     note: "seit Mitternacht")
            StatTile(title: "Empfangen", value: ByteFormat.short(usage?.bytesIn ?? 0),
                     note: "↑ \(ByteFormat.short(usage?.bytesOut ?? 0)) gesendet")
        }
    }

    private var chart: some View {
        Card(title: "Menge über die Zeit",
             subtitle: range == 24
                ? "Stundenfenster der letzten 24 Stunden"
                : "Tagesfenster der letzten 7 Tage") {
            let buckets = model.history(for: serviceId,
                                        hours: range,
                                        bucket: range == 24 ? 3600 : 86400)
            Picker("", selection: $range) {
                Text("24 Stunden").tag(24)
                Text("7 Tage").tag(24 * 7)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()

            if buckets.contains(where: { $0.total > 0 }) {
                Sparkline(buckets: buckets, tint: usage?.tint ?? .accentColor,
                          height: 90, barWidth: range == 24 ? 12 : 34)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(buckets.first.map { dateStamp($0.start) } ?? "")
                    Spacer()
                    Text("Spitze \(ByteFormat.short(buckets.map(\.total).max() ?? 0)) je Fenster")
                    Spacer()
                    Text("jetzt")
                }
                .font(.caption2).foregroundStyle(.tertiary)
            } else {
                Text("Keine Messdaten in diesem Zeitraum.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: 90, alignment: .center)
            }
        }
    }

    private var protocolCard: some View {
        Card(title: "Protokoll",
             subtitle: "Zeitpunkte von Sperre, Freigabe und Verkehr trotz Sperre") {
            let events = model.events(for: serviceId)
            if events.isEmpty {
                Text("Noch nichts protokolliert.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events.prefix(12)) { event in
                        EventRow(event: event, name: nil)
                    }
                }
            }
        }
    }

    private var leverCard: some View {
        Card(title: "Hebel", subtitle: "Womit dieser Dienst gestoppt wird") {
            if service.levers.isEmpty {
                Text("Kein Hebel hinterlegt — dieser Dienst lässt sich nicht sperren.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(service.levers.enumerated()), id: \.offset) { _, lever in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: lever.kind.needsRoot ? "key.fill" : "hand.raised.fill")
                                .font(.caption2)
                                .foregroundStyle(lever.kind.needsRoot ? Palette.leak : .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(leverName(lever.kind)).font(.callout)
                                if let note = lever.kind.bluntnessNote {
                                    Text(note).font(.caption2).foregroundStyle(.secondary)
                                }
                                if lever.kind.needsRoot {
                                    Text("braucht sudo").font(.caption2)
                                        .foregroundStyle(Palette.leak)
                                }
                            }
                        }
                    }
                }
            }
            if let note = service.note {
                Text(note).font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Button("Diesen Dienst aus der Liste entfernen", role: .destructive) {
                model.resetTracking(serviceId)
                dismiss()
            }
            .controlSize(.small)
        }
    }
}

func leverName(_ kind: LeverKind) -> String {
    switch kind {
    case .launchdFreeze: return "Systemdienst anhalten"
    case .processFreeze: return "App einfrieren"
    case .pfDomains:     return "Ziel-Adressen sperren"
    case .appPause:      return "Pause-Befehl der App"
    case .neFilter:      return "Netzwerkfilter"
    }
}

// MARK: - Protokoll

struct LogView: View {
    @ObservedObject var model: AppModel
    @State private var onlyAttempts = false

    private var events: [ServiceEvent] {
        onlyAttempts ? model.recentEvents.filter { $0.kind == .attempt } : model.recentEvents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Protokoll").font(.title2).fontWeight(.semibold)
                    Text("Wann etwas gesperrt oder freigegeben wurde — und wann trotz "
                       + "gesetzter Sperre Daten geflossen sind.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Toggle("Nur Durchbrüche", isOn: $onlyAttempts)
                        .toggleStyle(.switch).controlSize(.small)
                    Spacer()
                    Text("\(events.count) Einträge · 14 Tage")
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
            .padding(16)

            Divider()

            if events.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.largeTitle).foregroundStyle(.tertiary)
                    Text(onlyAttempts ? "Keine Durchbrüche" : "Noch nichts protokolliert")
                        .font(.headline).foregroundStyle(.secondary)
                    Text(onlyAttempts
                         ? "Durch eine gesetzte Sperre ist bisher nichts gekommen."
                         : "Sobald du etwas sperrst oder freigibst, steht es hier mit Zeitpunkt.")
                        .font(.caption).foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(events) { event in
                    EventRow(event: event,
                             name: model.catalog.serviceOrUnknown(id: event.serviceId).name)
                }
                .listStyle(.inset)
            }
        }
    }
}

struct EventRow: View {
    let event: ServiceEvent
    /// `nil` in der Detailansicht — dort ist der Dienst schon im Kopf genannt.
    let name: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.kind.symbol)
                .font(.caption)
                .foregroundStyle(event.kind.tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    if let name { Text(name).fontWeight(.medium) }
                    Text(event.kind.displayName)
                        .font(name == nil ? .callout : .caption)
                        .foregroundStyle(name == nil ? event.kind.tint : .secondary)
                    if event.bytes > 0 {
                        Text(ByteFormat.short(event.bytes))
                            .font(.caption).monospacedDigit()
                            .foregroundStyle(event.kind.tint)
                    }
                }
                if let detail = event.detail {
                    Text(detail).font(.caption2).foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(event.isEpisode
                     ? "\(dateStamp(event.at))–\(clockStamp(event.until))"
                     : dateStamp(event.at))
                    .font(.caption).monospacedDigit()
                Text(relativeAgo(event.at)).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Profile

struct ProfilesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Profile").font(.title2).fontWeight(.semibold)
                    Text("Eine Stufe sperrt Klassen, keine einzelnen Dienste — so greift sie "
                       + "auch für Dienste, die es beim Anlegen noch nicht gab. Was eine Stufe "
                       + "sperrt, legst du hier fest.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !model.policyState.inconsistentTiers.isEmpty {
                    warning
                }

                ForEach(PolicyTier.allCases.filter(\.isEditable), id: \.self) { tier in
                    TierEditor(tier: tier, model: model)
                }

                Card(title: "Immer geschützt",
                     subtitle: "Diese Klasse lässt sich keiner Stufe zuordnen — sonst könnte "
                             + "sich das Werkzeug selbst oder das VPN aussperren.") {
                    HStack(spacing: 6) {
                        Image(systemName: ServiceClass.essential.symbol)
                        Text(ServiceClass.essential.displayName).fontWeight(.medium)
                        Pill(text: "hart geschützt", tint: .green, symbol: "checkmark")
                    }
                }
            }
            .padding(16)
        }
    }

    private var warning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.leak)
            VStack(alignment: .leading, spacing: 2) {
                Text("Eine höhere Stufe sperrt weniger als eine niedrigere")
                    .fontWeight(.medium)
                Text("Betroffen: "
                   + model.policyState.inconsistentTiers.map(\.displayName).joined(separator: ", ")
                   + ". Die Budget-Automatik stuft nur nach oben — sie würde dabei lockern.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.leak.opacity(0.12)))
    }
}

struct TierEditor: View {
    let tier: PolicyTier
    @ObservedObject var model: AppModel

    private var classes: Set<ServiceClass> { model.blockedClasses(for: tier) }
    private var isCustom: Bool { model.policyState.isCustomized(tier) }
    private var isActive: Bool { model.tier == tier }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: tier.symbol)
                        .foregroundStyle(tier.tint)
                    Text(tier.displayName).font(.headline)
                    if isActive { Pill(text: "aktiv", tint: tier.tint, filled: true) }
                    if isCustom { Pill(text: "angepasst", tint: .secondary, symbol: "pencil") }
                    Spacer()
                    if isCustom {
                        Button("Voreinstellung") { model.resetTier(tier) }
                            .controlSize(.small)
                    }
                    Button(isActive ? "Aktiv" : "Aktivieren") { model.setTier(tier) }
                        .controlSize(.small)
                        .disabled(isActive)
                }

                Text(classes.isEmpty
                     ? "Sperrt nichts."
                     : "Sperrt: " + ServiceClass.allCases.filter { classes.contains($0) }
                        .map(\.displayName).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)],
                          alignment: .leading, spacing: 8) {
                    ForEach(ServiceClass.allCases.filter(\.isBlockable), id: \.self) { cls in
                        ClassToggle(cls: cls,
                                    isOn: classes.contains(cls),
                                    tint: tier.tint) {
                            model.toggleClass(cls, for: tier)
                        }
                    }
                }
            }
        }
    }
}

struct ClassToggle: View {
    let cls: ServiceClass
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? tint : Color.secondary.opacity(0.6))
                Image(systemName: cls.symbol)
                    .font(.caption)
                    .foregroundStyle(isOn ? tint : .secondary)
                Text(cls.displayName)
                    .font(.callout)
                    .foregroundStyle(isOn ? Color.primary : .secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isOn ? tint.opacity(0.12) : Palette.track.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isOn ? tint.opacity(0.35) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dienste

struct ServicesView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""

    private var grouped: [(ServiceClass, [Service])] {
        let filtered = model.catalog.services.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
        }
        return ServiceClass.allCases.compactMap { cls in
            let list = filtered.filter { $0.serviceClass == cls }.sorted { $0.name < $1.name }
            return list.isEmpty ? nil : (cls, list)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dienste").font(.title2).fontWeight(.semibold)
                Text("Der Katalog: was das Werkzeug kennt und womit es den Dienst stoppt. "
                   + "Einzelne Dienste lassen sich dauerhaft vom Profil ausnehmen.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)

            Divider()

            List {
                ForEach(grouped, id: \.0) { cls, services in
                    Section {
                        ForEach(services) { service in
                            ServiceDetailRow(service: service, model: model)
                        }
                    } header: {
                        HStack {
                            Label(cls.displayName, systemImage: cls.symbol)
                            Spacer()
                            Text(tierNote(for: cls)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .searchable(text: $search, prompt: "Dienst suchen")
        }
    }

    private func tierNote(for cls: ServiceClass) -> String {
        guard cls.isBlockable else { return "nie sperrbar" }
        let state = model.policyState
        guard let first = PolicyTier.allCases.sorted()
            .first(where: { state.blockedClasses(for: $0).contains(cls) })
        else { return "nur manuell" }
        return "ab „\(first.displayName)“"
    }
}

struct ServiceDetailRow: View {
    let service: Service
    @ObservedObject var model: AppModel

    private var isBlocked: Bool { model.blocked.contains { $0.id == service.id } }
    private var state: PolicyState { model.policyState }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if isBlocked {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.red)
                    }
                    Text(service.name).fontWeight(.medium)
                    if state.alwaysAllow.contains(service.id) {
                        Pill(text: "immer erlaubt", tint: .green, symbol: "checkmark")
                    }
                    if state.alwaysBlock.contains(service.id) {
                        Pill(text: "immer gesperrt", tint: .red, symbol: "lock.fill")
                    }
                }
                if let lever = service.levers.first {
                    HStack(spacing: 4) {
                        Text(leverName(lever.kind))
                        if let note = lever.kind.bluntnessNote {
                            Text("· \(note)")
                        }
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
                if let note = service.note {
                    Text(note).font(.caption2).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if service.isBlockable {
                Menu {
                    Button(isBlocked ? "Freigeben" : "Jetzt sperren") {
                        if isBlocked { model.unblock(service.id) } else { model.block(service) }
                    }
                    Divider()
                    Button("Immer erlauben") { model.setException(service, allow: true) }
                    Button("Immer sperren") { model.setException(service, allow: false) }
                    Button("Ausnahme entfernen") { model.setException(service, allow: nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton).fixedSize()
            } else {
                Image(systemName: "lock.shield").foregroundStyle(.tertiary)
                    .help("Systemkritisch — bewusst nicht sperrbar")
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Netze

struct NetworksView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Netze").font(.title2).fontWeight(.semibold)
                Text("Netze werden an der MAC-Adresse ihres Routers wiedererkannt — dafür "
                   + "braucht die App keine Ortungsdienste. Die Einstufung entscheidet, ob "
                   + "gesperrt wird und ob der Verbrauch aufs Budget zählt.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)

            Divider()

            List(model.networks, id: \.identity.id) { record in
                let isCurrent = record.identity.id == model.network.id
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill((isCurrent ? Color.accentColor : record.networkClass.tint)
                                .opacity(0.14))
                            .frame(width: 28, height: 28)
                        Image(systemName: isCurrent
                              ? "dot.radiowaves.left.and.right" : record.networkClass.symbol)
                            .font(.caption)
                            .foregroundStyle(isCurrent ? Color.accentColor : record.networkClass.tint)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(record.identity.label).fontWeight(.medium)
                            if isCurrent { Pill(text: "verbunden", tint: .accentColor) }
                        }
                        Text("\(record.identity.interface) · "
                           + "\(record.identity.gatewayMAC ?? record.identity.gatewayIP) · "
                           + "zuletzt \(relativeAgo(record.lastSeen))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { record.networkClass },
                        set: { model.setNetworkClass($0, for: record.identity.id) })) {
                            ForEach(NetworkClass.allCases, id: \.self) { cls in
                                Text(cls.displayName).tag(cls)
                            }
                        }
                        .labelsHidden().fixedSize()
                        .help(record.networkClass.explanation)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Budget

struct BudgetView: View {
    @ObservedObject var model: AppModel
    @State private var volumeText = "5 GB"
    @State private var endDate = Date().addingTimeInterval(14 * 86400)
    @State private var label = "Reise"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Budget").font(.title2).fontWeight(.semibold)
                    Text("Nur Verbrauch in Netzen der Klasse „teuer“ oder „begrenzt“ zählt.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let status = model.budgetStatus {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(status.budget.label).font(.headline)
                                Spacer()
                                Pill(text: status.light.text, tint: status.light.tint,
                                     symbol: "circle.fill")
                            }
                            UsageBar(fraction: 1 - status.remainingFraction,
                                     tint: status.light.tint, height: 8)
                            HStack(spacing: 10) {
                                StatTile(title: "Übrig",
                                         value: ByteFormat.short(status.remainingBytes),
                                         note: "von \(ByteFormat.short(status.budget.totalBytes))",
                                         tint: status.light.tint)
                                StatTile(title: "Restlaufzeit",
                                         value: String(format: "%.1f", status.remainingDays),
                                         note: "Tage")
                                StatTile(title: "Tagesbudget",
                                         value: ByteFormat.short(status.dailyAllowance),
                                         note: "heute \(ByteFormat.short(status.usedTodayBytes))")
                                StatTile(title: "Hochrechnung",
                                         value: ByteFormat.short(status.projectedToday),
                                         note: "für heute",
                                         tint: status.light.tint)
                            }
                            Button("Budget löschen", role: .destructive) { model.saveBudget(nil) }
                                .controlSize(.small)
                        }
                    }
                }

                Card(title: "Neues Budget",
                     subtitle: "Volumen und Enddatum des Tarifs — daraus ergibt sich das Tagesbudget.") {
                    // Beschriftung über dem Feld statt daneben: Nebeneinander
                    // bricht „Name" in einem schmalen Fenster mitten im Wort um.
                    HStack(alignment: .bottom, spacing: 18) {
                        field("Volumen") {
                            TextField("5 GB", text: $volumeText).frame(width: 92)
                        }
                        field("Bis") {
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        field("Name") {
                            TextField("Reise", text: $label).frame(width: 130)
                        }
                        Spacer()
                        Button("Setzen") { save() }
                            .buttonStyle(.borderedProminent)
                            .disabled(ByteFormat.parse(volumeText) == nil)
                    }
                    if ByteFormat.parse(volumeText) == nil {
                        Text("Volumen nicht verstanden — z. B. „5 GB“ oder „500 MB“")
                            .font(.caption).foregroundStyle(.red)
                    }
                }

                Card(title: "Automatik",
                     subtitle: "Stuft hoch, wenn die Hochrechnung über dem Tagesbudget liegt "
                             + "oder weniger als 15 % übrig sind. Zurückgestuft wird nur von "
                             + "Hand — sonst pendelt das Profil.") {
                    Toggle("Bei knappem Budget automatisch hochstufen", isOn: Binding(
                        get: { model.policyState.autoEscalate },
                        set: { model.setAutoEscalate($0) }))
                        .toggleStyle(.switch)
                }
            }
            .padding(16)
        }
    }

    private func field<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(text: title)
            content()
        }
    }

    private func save() {
        guard let bytes = ByteFormat.parse(volumeText) else { return }
        model.saveBudget(Budget(totalBytes: bytes, startsAt: Date(),
                                endsAt: endDate, label: label))
    }
}
