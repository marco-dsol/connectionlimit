import Foundation
import ConnLimitCore

/// Die Hilfe. Eine Funktion statt einer Konstante: Die Texte hängen an der
/// eingestellten Sprache.
func usageText() -> String {
    func line(_ command: String, _ text: String) -> String {
        command.count < 28
            ? "  " + Term.pad(command, 28) + text
            : "  " + command + "\n" + String(repeating: " ", count: 30) + text
    }
    let svc = L("<dienst>")
    return [
        Term.bold("connlimit") + " — " + L("Datenverbindungen auf dem Mac sehen und begrenzen"),
        "",
        Term.bold(L("SEHEN")),
        line("tracked [--active] [--limit 30]", L("Dauerliste: jeder Dienst, der je Daten brauchte")),
        line("top [--since 1h|today|7d] [--metered] [--limit 20]", L("Verbrauch pro Dienst im Zeitraum")),
        line("watch [--interval 2]", L("Live-Ansicht, wer gerade sendet")),
        line("history \(svc) [--since 24h] [--bucket 1h]", L("Mengenverlauf über die Zeit")),
        line("events [\(svc)] [--attempts] [--since 7d]", L("Protokoll: Sperren, Freigaben, Verkehr trotz Sperre")),
        line("status", L("Netz, Profil, Budget, aktive Sperren")),
        line("services [--class sync]", L("Dienstkatalog mit Hebeln")),
        "",
        Term.bold(L("BEGRENZEN")),
        line("block \(svc) [--for 30m]", L("Dienst sperren, wahlweise befristet")),
        line("allow \(svc) [--for 30m]", L("Freigeben; mit --for befristet, danach wieder gesperrt")),
        line("unblock-all", L("Not-Aus: alle Sperren aufheben")),
        line(L("profile [aus|sparsam|urlaub|notfall|auto]"), L("Eskalationsstufe setzen oder anzeigen")),
        line("except <allow|block|clear> \(svc)", L("Dauerhafte Ausnahme vom Profil")),
        line(L("profile edit <stufe> <klassen…>"), L("Festlegen, was eine Stufe sperrt")),
        line("reset \(svc) | --all", L("Dauerliste zurücksetzen")),
        "",
        Term.bold(L("EINRICHTEN")),
        line("net [list|set|name]", L("Netze einstufen (frei / teuer / begrenzt)")),
        line("budget [show|set|clear]", L("Reisebudget, z. B. budget set 5GB --until 2026-09-06")),
        line("run [--read-only] [-v]", L("Hintergrunddienst: messen und durchsetzen")),
        line("doctor", L("Prüft, welche Hebel auf diesem Mac verfügbar sind")),
        line("install-pf / uninstall-pf", L("PF-Anchor für Domain-Sperren (root)")),
        line("lang [de|en|auto]", L("Sprache von App und Terminal")),
        "",
        Term.dim(L("Konzept und Grenzen: README.md")),
    ].joined(separator: "\n")
}

let raw = Array(CommandLine.arguments.dropFirst())
let args = Args(raw)
let command = args[0] ?? "help"

do {
    switch command {
    case "tracked", "liste": try cmdTracked(args)
    case "history", "verlauf": try cmdHistory(args)
    case "events", "protokoll": try cmdEvents(args)
    case "reset":          try cmdReset(args)
    case "top":            try cmdTop(args)
    case "watch":          try cmdWatch(args)
    case "status":         try cmdStatus(args)
    case "services":       try cmdServices(args)
    case "block":          try cmdBlock(args)
    case "allow", "unblock": try cmdAllow(args)
    case "unblock-all":    try cmdUnblockAll(args)
    case "profile":        try cmdProfile(args)
    case "except":         try cmdExcept(args)
    case "net":            try cmdNet(args)
    case "budget":         try cmdBudget(args)
    case "run":            try cmdRun(args)
    case "doctor":         try cmdDoctor(args)
    case "install-pf":     try cmdInstallPF(args)
    case "uninstall-pf":   try cmdUninstallPF(args)
    case "lang", "sprache": try cmdLang(args)
    case "help", "--help", "-h":
        print(usageText())
    default:
        print(usageText())
        FileHandle.standardError.write(("\n" + L("Unbekannter Befehl: %@", command) + "\n").data(using: .utf8)!)
        exit(2)
    }
} catch {
    FileHandle.standardError.write(
        (Term.red(L("Fehler: ")) + (error.localizedDescription) + "\n").data(using: .utf8)!)
    exit(1)
}
