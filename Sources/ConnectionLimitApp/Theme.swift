import SwiftUI
import ConnLimitCore

// MARK: - Farbsprache
//
// Vier Farben, vier Aussagen. Mehr braucht diese App nicht, und weniger wäre
// mehrdeutig:
//
//   grün   — bewegt gerade Daten
//   rot    — gesperrt
//   orange — gesperrt, und trotzdem fließt etwas (der wichtigste Fall)
//   grau   — bekannt, aber still
//
// Die Reihenfolge ist eine Rangfolge: Orange schlägt Rot schlägt Grün. Wer
// eine Sperre gesetzt hat, muss zuerst sehen, ob sie hält.

enum Palette {
    static let active = Color.green
    static let blocked = Color.red
    static let leak = Color.orange
    static let idle = Color.secondary

    static let cardBackground = Color.primary.opacity(0.035)
    static let cardBorder = Color.primary.opacity(0.08)
    static let track = Color.primary.opacity(0.08)
}

extension ServiceUsage {
    /// Die Farbe der Zeile.
    var tint: Color {
        if isLeaking() { return Palette.leak }
        if isBlocked   { return Palette.blocked }
        if isActive()  { return Palette.active }
        return Palette.idle
    }

    var statusText: String {
        if isLeaking() { return L("trotz Sperre aktiv") }
        if isBlocked   { return L("gesperrt") }
        if isActive()  { return L("aktiv") }
        return L("still")
    }

    var statusSymbol: String {
        if isLeaking() { return "exclamationmark.triangle.fill" }
        if isBlocked   { return "lock.fill" }
        if isActive()  { return "dot.radiowaves.left.and.right" }
        return "moon.zzz"
    }
}

extension NetworkClass {
    var tint: Color {
        switch self {
        case .free:    return .green
        case .metered: return .red
        case .limited: return .orange
        case .unknown: return .secondary
        }
    }
    var symbol: String {
        switch self {
        case .free:    return "wifi"
        case .metered: return "exclamationmark.triangle.fill"
        case .limited: return "gauge.with.dots.needle.33percent"
        case .unknown: return "questionmark.circle"
        }
    }
    var explanation: String {
        switch self {
        case .free:    return L("Flatrate — es wird nichts gesperrt und nichts aufs Budget gezählt.")
        case .metered: return L("Teuer — hier greift der Urlaubsmodus, der Verbrauch zählt aufs Budget.")
        case .limited: return L("Begrenzt — sparsames Profil, Verbrauch zählt aufs Budget.")
        case .unknown: return L("Noch nicht eingestuft — solange wird bewusst nichts gesperrt.")
        }
    }
}

extension PolicyTier {
    var tint: Color {
        switch self {
        case .off:       return .secondary
        case .frugal:    return .blue
        case .vacation:  return .orange
        case .emergency: return .red
        }
    }
    var symbol: String {
        switch self {
        case .off:       return "circle"
        case .frugal:    return "leaf"
        case .vacation:  return "sun.max"
        case .emergency: return "exclamationmark.octagon"
        }
    }
}

extension ServiceClass {
    var symbol: String {
        switch self {
        case .essential: return "lock.shield"
        case .update:    return "arrow.down.circle"
        case .backup:    return "externaldrive"
        case .telemetry: return "antenna.radiowaves.left.and.right"
        case .media:     return "play.circle"
        case .sync:      return "arrow.triangle.2.circlepath"
        case .mail:      return "envelope"
        case .browser:   return "globe"
        case .messaging: return "bubble.left.and.bubble.right"
        case .other:     return "questionmark.app"
        }
    }
}

extension BudgetStatus.Light {
    var tint: Color {
        switch self {
        case .green:  return .green
        case .yellow: return .orange
        case .red:    return .red
        }
    }
}

extension ServiceEvent.Kind {
    var tint: Color {
        switch self {
        case .blocked:  return .red
        case .released: return .green
        case .attempt:  return .orange
        case .reset:    return .secondary
        }
    }
    var symbol: String {
        switch self {
        case .blocked:  return "lock.fill"
        case .released: return "lock.open"
        case .attempt:  return "exclamationmark.triangle.fill"
        case .reset:    return "arrow.counterclockwise"
        }
    }
}

// MARK: - Bausteine

/// Balken für Verbrauchsanteile — bewusst schlicht, damit die Zahl im
/// Vordergrund bleibt.
struct UsageBar: View {
    var fraction: Double
    var tint: Color = .accentColor
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule().fill(tint.opacity(0.8))
                    .frame(width: max(2, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
    }
}

/// Mengenverlauf als Balkenreihe.
///
/// Leere Fenster bleiben leer, statt auf der untersten Stufe zu stehen — sonst
/// sähe Stille wie schwacher Verkehr aus. Genau das wäre die eine Aussage,
/// die man aus einem Verlauf nicht falsch ablesen darf.
struct Sparkline: View {
    var buckets: [HistoryBucket]
    var tint: Color = .accentColor
    var height: CGFloat = 22
    var barWidth: CGFloat = 3
    /// Länge eines Fensters — nur für den Hinweistext.
    var bucketLength: TimeInterval = 3600

    private var peak: Int64 { max(1, buckets.map(\.total).max() ?? 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(buckets) { bucket in
                let fraction = Double(bucket.total) / Double(peak)
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(bucket.total > 0 ? tint.opacity(0.85) : Palette.track)
                    .frame(width: barWidth,
                           height: bucket.total > 0
                               ? max(2, height * CGFloat(fraction))
                               : 1.5)
            }
        }
        .frame(height: height, alignment: .bottom)
        .help(helpText)
    }

    private var helpText: String {
        if buckets.isEmpty { return L("Kein Verlauf") }
        return bucketLength >= 86400
            ? L("Verlauf der letzten %@ Tage", buckets.count)
            : L("Verlauf der letzten %@ Stunden", buckets.count)
    }
}

/// Kleines Etikett für einen Zustand.
struct Pill: View {
    var text: String
    var tint: Color
    var symbol: String?
    var filled = false

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 8, weight: .bold))
            }
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(tint.opacity(filled ? 0.9 : 0.14)))
        .foregroundStyle(filled ? Color.white : tint)
    }
}

/// Der pulsierende Punkt für „gerade aktiv". Bewegung nur dort, wo sie eine
/// Information trägt — sonst nirgends.
struct LivePulse: View {
    var tint: Color = Palette.active
    @State private var on = false

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 7, height: 7)
            .overlay(
                Circle().stroke(tint.opacity(on ? 0 : 0.6), lineWidth: 3)
                    .scaleEffect(on ? 2.2 : 1)
            )
            .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: on)
            .onAppear { on = true }
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.8)
    }
}

/// Kennzahl-Kachel für den Kopf des Fensters.
struct StatTile: View {
    var title: String
    var value: String
    var note: String?
    var tint: Color = .primary
    var symbol: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 10))
                }
                SectionLabel(text: title)
            }
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let note {
                Text(note).font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Palette.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Palette.cardBorder, lineWidth: 1))
    }
}

/// Rahmen für abgesetzte Bereiche — ersetzt GroupBox, weil dessen Titelzeile
/// im dunklen Erscheinungsbild unruhig wirkt.
struct Card<Content: View>: View {
    var title: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Palette.cardBorder, lineWidth: 1))
    }
}

// MARK: - Zeitangaben

//
// Die Formate selbst liegen im Kern (`DisplayTime`), damit Fenster und
// Terminal dieselbe Zeit gleich schreiben.

func relativeRemaining(_ date: Date) -> String { DisplayTime.remaining(until: date) }

func relativeAgo(_ date: Date) -> String { DisplayTime.ago(date) }

func dateStamp(_ date: Date) -> String { DisplayTime.stamp(date) }

func clockStamp(_ date: Date) -> String { DisplayTime.clock(date) }

// MARK: - Sprache

/// Umschalter für die Sprache: Automatik (wie macOS), Deutsch, English.
/// Die Sprachnamen stehen in ihrer eigenen Sprache — wer die falsche
/// erwischt hat, findet so trotzdem zurück.
struct LanguageMenu: View {
    @ObservedObject var model: AppModel
    var compact = false

    var body: some View {
        Menu {
            Picker(L("Sprache"), selection: Binding(
                get: { model.languagePreference },
                set: { model.setLanguage($0) })) {
                    Text(L("Wie macOS")).tag(LanguagePreference.system)
                    Divider()
                    Text(Language.de.nativeName).tag(LanguagePreference.de)
                    Text(Language.en.nativeName).tag(LanguagePreference.en)
                }
                .pickerStyle(.inline)
        } label: {
            if compact {
                Text(model.language.shortCode)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            } else {
                Label(model.language.nativeName, systemImage: "globe")
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(L("Sprache"))
    }
}
