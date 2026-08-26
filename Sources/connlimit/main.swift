import Foundation
import ConnLimitCore

let usage = """
\(Term.bold("connlimit")) — Datenverbindungen auf dem Mac sehen und begrenzen

\(Term.bold("SEHEN"))
  tracked [--active] [--limit 30]
                              Dauerliste: jeder Dienst, der je Daten brauchte
  top [--since 1h|today|7d] [--metered] [--limit 20]
                              Verbrauch pro Dienst im Zeitraum
  watch [--interval 2]        Live-Ansicht, wer gerade sendet
  history <dienst> [--since 24h] [--bucket 1h]
                              Mengenverlauf über die Zeit
  events [<dienst>] [--attempts] [--since 7d]
                              Protokoll: Sperren, Freigaben, Verkehr trotz Sperre
  status                      Netz, Profil, Budget, aktive Sperren
  services [--class sync]     Dienstkatalog mit Hebeln

\(Term.bold("BEGRENZEN"))
  block <dienst> [--for 30m]  Dienst sperren, wahlweise befristet
  allow <dienst> [--for 30m]  Freigeben; mit --for befristet, danach wieder gesperrt
  unblock-all                 Not-Aus: alle Sperren aufheben
  profile [aus|sparsam|urlaub|notfall|auto]
                              Eskalationsstufe setzen oder anzeigen
  except <allow|block|clear> <dienst>
                              Dauerhafte Ausnahme vom Profil
  profile edit <stufe> <klassen…>
                              Festlegen, was eine Stufe sperrt
  reset <dienst> | --all      Dauerliste zurücksetzen

\(Term.bold("EINRICHTEN"))
  net [list|set|name]         Netze einstufen (frei / teuer / begrenzt)
  budget [show|set|clear]     Reisebudget, z. B. budget set 5GB --until 2026-09-06
  run [--read-only] [-v]      Hintergrunddienst: messen und durchsetzen
  doctor                      Prüft, welche Hebel auf diesem Mac verfügbar sind
  install-pf / uninstall-pf   PF-Anchor für Domain-Sperren (root)

\(Term.dim("Konzept und Grenzen: README.md"))
"""

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
    case "help", "--help", "-h":
        print(usage)
    default:
        print(usage)
        FileHandle.standardError.write("\nUnbekannter Befehl: \(command)\n".data(using: .utf8)!)
        exit(2)
    }
} catch {
    FileHandle.standardError.write(
        (Term.red("Fehler: ") + (error.localizedDescription) + "\n").data(using: .utf8)!)
    exit(1)
}
