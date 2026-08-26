import Foundation

/// Mitgelieferter Dienstkatalog.
///
/// Ergänzungen des Nutzers kommen aus
/// `~/Library/Application Support/at.mitsol.connectionlimit/catalog.json`
/// und überschreiben Einträge mit gleicher `id`.
public enum BuiltinCatalog {

    private static func svc(_ id: String, _ name: String, _ cls: ServiceClass,
                            proc: [String] = [], bundle: [String] = [], path: [String] = [],
                            levers: [LeverSpec] = [], note: String? = nil) -> Service {
        Service(id: id, name: name, serviceClass: cls,
                match: ServiceMatch(processes: proc, bundleIds: bundle, pathPrefixes: path),
                levers: levers, note: note)
    }

    public static let services: [Service] = essential + updates + backup + sync + media + telemetry + mail + interactive

    // MARK: - essential (nie sperrbar)

    static let essential: [Service] = [
        svc("dns", "DNS-Auflösung", .essential,
            proc: ["mDNSResponder", "mDNSResponderHelper", "dnsextd"],
            note: "Ohne DNS funktioniert nichts. Verbraucht selbst kaum Volumen."),
        svc("time", "Zeitabgleich", .essential, proc: ["timed", "ntpd"]),
        svc("network-stack", "Netzwerk-Stack", .essential,
            proc: ["configd", "networkd", "symptomsd", "nehelper", "netbiosd",
                   "airportd", "wifip2pd", "wifivelocityd", "wifianalyticsd"]),
        svc("vpn", "VPN", .essential,
            proc: ["NEIKEv2Provider", "racoon", "wireguard-go", "Tailscale",
                   "tailscaled", "openvpn", "com.wireguard.macos"],
            note: "Ein gesperrtes VPN würde die Verbindung ganz kappen."),
        svc("apple-push", "Apple Push", .essential, proc: ["apsd"],
            note: "Transportiert iMessage- und Mail-Hinweise. Sehr geringes Volumen — sperren lohnt nicht."),
        svc("connectionlimit", "ConnectionLimit", .essential,
            proc: ["connlimit", "connlimit-helper", "ConnectionLimit"]),
        svc("security", "Sicherheitsupdates", .essential,
            proc: ["XProtect", "XProtectRemediatorScan", "syspolicyd", "trustd", "ocspd"],
            note: "Malware-Definitionen. Klein und sicherheitsrelevant — bewusst nicht sperrbar."),
    ]

    // MARK: - update

    static let updates: [Service] = [
        svc("macos-update", "macOS Update", .update,
            proc: ["softwareupdated", "SoftwareUpdateNotificationManager", "nsurlsessiond"],
            levers: [.launchdFreeze(jobs: ["com.apple.softwareupdated"]),
                     .pfDomains(domains: ["swscan.apple.com", "swcdn.apple.com",
                                          "swdist.apple.com", "swdownload.apple.com"])],
            note: "Der mit Abstand größte einzelne Posten — ein macOS-Update sind mehrere GB."),
        svc("app-store", "App Store", .update,
            proc: ["appstoreagent", "storedownloadd", "storeassetd", "storekitagent"],
            bundle: ["com.apple.AppStore"],
            levers: [.launchdFreeze(jobs: ["com.apple.appstoreagent", "com.apple.storedownloadd"])]),
        svc("homebrew", "Homebrew", .update,
            proc: ["brew"], path: ["/opt/homebrew/", "/usr/local/Homebrew/"],
            levers: [.pfDomains(domains: ["formulae.brew.sh", "ghcr.io", "pkg-containers.githubusercontent.com"])]),
        svc("docker", "Docker", .update,
            proc: ["com.docker.backend", "com.docker.build", "Docker"],
            bundle: ["com.docker.docker"],
            levers: [.processFreeze],
            note: "Image-Pulls sind schnell mehrere GB."),
        svc("jetbrains-update", "JetBrains Updates", .update,
            proc: ["JetBrains Toolbox"], levers: [.processFreeze]),
    ]

    // MARK: - backup

    static let backup: [Service] = [
        svc("time-machine", "Time Machine", .backup,
            proc: ["backupd", "backupd-helper"],
            levers: [.launchdFreeze(jobs: ["com.apple.backupd"])],
            note: "Nur relevant bei Netzwerk-Backupziel."),
        svc("backblaze", "Backblaze", .backup,
            proc: ["bzbmenu", "bztransmit", "bzfilelist"],
            levers: [.processFreeze]),
        svc("ccc", "Carbon Copy Cloner", .backup,
            proc: ["Carbon Copy Cloner", "CCC Dashboard"],
            bundle: ["com.bombich.ccc"], levers: [.processFreeze]),
    ]

    // MARK: - sync

    static let sync: [Service] = [
        svc("icloud-drive", "iCloud Drive", .sync,
            proc: ["bird", "cloudd", "fileproviderd"],
            levers: [.launchdFreeze(jobs: ["com.apple.bird", "com.apple.cloudd"]),
                     .pfDomains(domains: ["icloud.com", "icloud-content.com", "apple-cloudkit.com"])],
            note: "Fotos hängen separat an 'iCloud Fotos'."),
        svc("icloud-photos", "iCloud Fotos", .sync,
            proc: ["photoanalysisd", "photolibraryd", "cloudphotod", "mediaanalysisd"],
            levers: [.launchdFreeze(jobs: ["com.apple.photoanalysisd", "com.apple.cloudphotod"])],
            note: "Lädt ganze Mediatheken nach — im Urlaub der teuerste Sync."),
        svc("icloud-backup", "iCloud Sicherung", .sync,
            proc: ["nsurlstoraged", "CloudKeychainProxy", "akd"],
            levers: [.launchdFreeze(jobs: ["com.apple.nsurlstoraged"])]),
        svc("onedrive", "OneDrive", .sync,
            proc: ["OneDrive", "OneDrive Sync Service", "OneDriveStandaloneUpdater"],
            bundle: ["com.microsoft.OneDrive"],
            levers: [.processFreeze,
                     .pfDomains(domains: ["onedrive.live.com", "storage.live.com", "sharepoint.com"])]),
        svc("dropbox", "Dropbox", .sync,
            proc: ["Dropbox", "DropboxMacUpdate"], bundle: ["com.getdropbox.dropbox"],
            levers: [.processFreeze,
                     .pfDomains(domains: ["dropbox.com", "dropboxapi.com", "dropboxusercontent.com"])]),
        svc("nextcloud", "Nextcloud", .sync,
            proc: ["Nextcloud", "nextcloudcmd"], bundle: ["com.nextcloud.desktopclient"],
            levers: [.processFreeze]),
        svc("google-drive", "Google Drive", .sync,
            proc: ["Google Drive", "FileProviderExtension"],
            bundle: ["com.google.drivefs"],
            levers: [.processFreeze]),
        svc("adobe-cc", "Adobe Creative Cloud", .sync,
            proc: ["Creative Cloud", "AdobeIPCBroker", "Core Sync", "AdobeCRDaemon"],
            levers: [.processFreeze],
            note: "Lädt Schriften und Updates ungefragt nach."),
    ]

    // MARK: - media

    static let media: [Service] = [
        svc("spotify", "Spotify", .media,
            proc: ["Spotify", "Spotify Helper"], bundle: ["com.spotify.client"],
            levers: [.pfDomains(domains: ["spotify.com", "scdn.co", "spotifycdn.com"]),
                     .processFreeze],
            note: "Lädt Playlists im Hintergrund vor."),
        svc("apple-media", "Apple Musik & TV", .media,
            proc: ["AMPLibraryAgent", "AMPDeviceDiscoveryAgent", "Music", "TV", "amsengagementd"],
            levers: [.launchdFreeze(jobs: ["com.apple.AMPLibraryAgent"])]),
        svc("podcasts", "Podcasts", .media,
            proc: ["podcastd", "Podcasts"],
            levers: [.launchdFreeze(jobs: ["com.apple.podcasts.PodcastContentService"])]),
        svc("steam", "Steam", .media,
            proc: ["steam_osx", "steamwebhelper", "Steam Helper"],
            bundle: ["com.valvesoftware.steam"],
            levers: [.processFreeze],
            note: "Spiele-Updates sind zweistellige GB-Beträge."),
    ]

    // MARK: - telemetry

    static let telemetry: [Service] = [
        svc("apple-diagnostics", "Apple Diagnose", .telemetry,
            proc: ["analyticsd", "SubmitDiagInfo", "ReportCrash", "spindump",
                   "osanalyticshelper", "diagnosticd"],
            levers: [.launchdFreeze(jobs: ["com.apple.analyticsd",
                                           "com.apple.osanalytics.osanalyticshelper"])]),
        svc("microsoft-telemetry", "Microsoft Update & Telemetrie", .telemetry,
            proc: ["Microsoft AU Daemon", "Microsoft Update Assistant", "Microsoft AutoUpdate"],
            levers: [.processFreeze]),
        svc("google-update", "Google Update", .telemetry,
            proc: ["GoogleSoftwareUpdateAgent", "GoogleSoftwareUpdateDaemon", "ksfetch"],
            levers: [.processFreeze]),
        svc("continuity", "Continuity & Handoff", .telemetry,
            proc: ["rapportd", "sharingd", "UniversalControl", "identityservice",
                   "replicatord", "AirPlayXPCHelper"],
            levers: [.launchdFreeze(jobs: ["com.apple.rapportd", "com.apple.sharingd"])],
            note: "Spart wenig Volumen, funkt aber im Urlaub ohne Nutzen ständig."),
    ]

    // MARK: - mail

    static let mail: [Service] = [
        svc("apple-mail", "Apple Mail", .mail,
            proc: ["Mail", "MailCacheDelivery", "mailfetchd"], bundle: ["com.apple.mail"],
            levers: [.processFreeze],
            note: "Einfrieren macht die App unbedienbar — besser Timer-Freigabe nutzen."),
        svc("outlook", "Microsoft Outlook", .mail,
            proc: ["Microsoft Outlook"], bundle: ["com.microsoft.Outlook"],
            levers: [.processFreeze],
            note: "Lädt ganze Postfächer vor. Einfrieren macht die App unbedienbar."),
        svc("thunderbird", "Thunderbird", .mail,
            proc: ["thunderbird"], bundle: ["org.mozilla.thunderbird"],
            levers: [.processFreeze]),
    ]

    // MARK: - browser & messaging (nur messen)

    static let interactive: [Service] = [
        svc("chrome", "Google Chrome", .browser,
            proc: ["Google Chrome", "Google Chrome Helper"],
            bundle: ["com.google.Chrome"], levers: [.processFreeze],
            note: "Meist der größte Posten. Sichtbar zu machen bringt mehr, als ihn zu sperren."),
        svc("safari", "Safari", .browser,
            proc: ["Safari", "com.apple.WebKit.Networking"],
            bundle: ["com.apple.Safari"], levers: [.processFreeze]),
        svc("firefox", "Firefox", .browser,
            proc: ["firefox"], bundle: ["org.mozilla.firefox"], levers: [.processFreeze]),
        svc("arc", "Arc", .browser, proc: ["Arc"], bundle: ["company.thebrowser.Browser"],
            levers: [.processFreeze]),

        svc("signal", "Signal", .messaging, proc: ["Signal"], bundle: ["org.whispersystems.signal-desktop"]),
        svc("whatsapp", "WhatsApp", .messaging, proc: ["WhatsApp"], bundle: ["desktop.WhatsApp"]),
        svc("telegram", "Telegram", .messaging, proc: ["Telegram"], bundle: ["ru.keepcoder.Telegram"]),
        svc("teams", "Microsoft Teams", .messaging,
            proc: ["MSTeams", "Microsoft Teams"], bundle: ["com.microsoft.teams2"],
            levers: [.processFreeze],
            note: "Video kostet viel — im Notfallmodus bewusst manuell sperren."),
        svc("slack", "Slack", .messaging, proc: ["Slack"], bundle: ["com.tinyspeck.slackmacgap"],
            levers: [.processFreeze]),
        svc("zoom", "Zoom", .messaging, proc: ["zoom.us"], bundle: ["us.zoom.xos"],
            levers: [.processFreeze]),
        svc("imessage", "Nachrichten", .messaging,
            proc: ["Messages", "imagent", "IMTransferAgent"], bundle: ["com.apple.MobileSMS"]),
    ]
}
