# ---
# id: "50-mediNix-default"
# title: "mediNix Master Boilerplate (SSoT, auto-imports all decades)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 5
# last_reviewed: 2026-08-11
# links:
# provides: ["options.medinix"]
# requires: ["lib/registry", "lib/service-factory"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# adr: ADR-5043
# ---

# 50-mediNix Master Boilerplate (SSoT)
#
# Portable module entrypoint. Auto-imports every XX-domain/NNN-*.nix module
# (flat structure, ADR-0000 §9). No hardcoded import list.
#
# Options API ported from grapefruit89/mediNix (709-line default.nix), made
# portable: no my.* references, all paths/domains via options (Regel 3).
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.medinix;

  # Helper: optional package override (null = nixpkgs default)
  mkPackageOption =
    svc:
    lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für ${svc}.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

  # Auto-import: every XX-domain/NNN-*.nix module (lib.pipe für Idiomatik)
  moduleFiles =
    let
      entries = builtins.readDir ./.;
      isModuleDir = n: t: t == "directory" && builtins.match "^[0-9]{2}-.*" n != null;
      importFromDir =
        dir:
        let
          files = builtins.readDir (./. + "/${dir}");
        in
        map (n: ./. + "/${dir}/${n}") (
          builtins.attrNames (
            lib.filterAttrs (n: t: t == "regular" && builtins.match "^[0-9]{3}-.*\\.nix$" n != null) files
          )
        );
    in
    lib.pipe entries [
      (lib.filterAttrs isModuleDir)
      builtins.attrNames
      (map importFromDir)
      lib.flatten
    ];
in
{
  imports = moduleFiles;

  options.medinix = {

    hostIntegration = {
      reverseProxy = lib.mkOption {
        type = lib.types.enum [
          "external"
          "managed"
          "off"
        ];
        default = "off";
        description = ''
          Ownership of the host reverse proxy. "off" (default) = mediNix makes
          NO assumption and does not touch a host Caddy — import does not mean
          take over. "managed" = mediNix enables services.caddy. "external" =
          a compatible host Caddy already exists (must be enabled by the host).
        '';
      };
      nftables = lib.mkOption {
        type = lib.types.enum [
          "external"
          "managed"
          "off"
        ];
        default = "external";
      };
      firewall = lib.mkOption {
        type = lib.types.enum [
          "external"
          "managed"
          "off"
        ];
        default = "external";
      };
      storage = lib.mkOption {
        type = lib.types.enum [
          "external"
          "managed"
          "off"
        ];
        default = "external";
      };
      vpn = lib.mkOption {
        type = lib.types.enum [
          "external"
          "managed"
          "off"
        ];
        default = "external";
      };
    };

    host = {
      credentials = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Paths to the TPM-sealed .cred files provided by the host. (e.g. usenet-server = /var/lib/credstore/usenet.cred)";
      };
      # Future host facts can be added here
    };

    recommended = {
      sysctl = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        internal = true;
        default = { };
      };
      nftables = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        internal = true;
        default = { };
      };
      mountOptions = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        internal = true;
        default = { };
      };
      firewall = {
        checkReversePath = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          internal = true;
          default = null;
        };
        extraReversePathFilterRules = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          internal = true;
          default = null;
        };
      };
    };

    enable = lib.mkEnableOption "Standalone Media Stack Module";

    cli = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "medinix CLI-Tool installieren (check/repair/status/vpn/secrets).";
      };
    };

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "media.example.com";
      description = ''
        Optionale Unicast-Base-Domain für die L2-vHosts ({service}.{domain}).
        null = KEINE L2-Namen. L1-mDNS ({service}.local) läuft unabhängig immer.
        WICHTIG: NIEMALS auf .local enden — .local ist Multicast-DNS (RFC 6762).
      '';
    };

    # --- Service enable + package overrides ---
    jellyfin = {
      enable = lib.mkEnableOption "Jellyfin Media Server";
      package = mkPackageOption "jellyfin";
      adminPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Pfad zur verschlüsselten Admin-Passwort-Datei (systemd-creds encrypt).
                    ADR-5510: Jellyfin speichert First-Run-Status in DB (nicht Config) — Passwort
                    MUSS vor dem ersten Start da sein (LoadCredentialEncrypted). Ohne: Web-UI blockiert.'';
      };
      # Jellyfin Admin (First-Run Bootstrap) — TPM-cred Workflow
      adminPasswordCredential = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Pfad zur .cred-Datei (systemd-creds TPM-verschlüsselt) für Jellyfin Admin-Passwort.
          Wird via LoadCredentialEncrypted als mediNix-jellyfin-admin gemountet.
        '';
      };
    };
    seerr = {
      enable = lib.mkEnableOption "Seerr request manager (https://seerr.dev)";
      package = mkPackageOption "seerr";
    };
    bazarr = {
      enable = lib.mkEnableOption "Bazarr Subtitle Downloader (Sonarr/Radarr)";
      package = mkPackageOption "bazarr";
    };
    sonarr = {
      enable = lib.mkEnableOption "Sonarr TV Series Manager";
      package = mkPackageOption "sonarr";
      rootFolder = lib.mkOption {
        type = lib.types.str;
        default = cfg.storage.mediaRoot + "/series";
        description = "Arr root folder (API-configured via provisioning).";
      };
      qualityProfile = lib.mkOption {
        type = lib.types.str;
        default = "HD-1080p";
        description = "Arr quality profile name (API-configured via provisioning).";
      };
    };
    radarr = {
      enable = lib.mkEnableOption "Radarr Movies Manager";
      package = mkPackageOption "radarr";
      rootFolder = lib.mkOption {
        type = lib.types.str;
        default = cfg.storage.mediaRoot + "/movies";
        description = "Arr root folder (API-configured via provisioning).";
      };
      qualityProfile = lib.mkOption {
        type = lib.types.str;
        default = "HD-1080p";
        description = "Arr quality profile name (API-configured via provisioning).";
      };
    };
    readarr = {
      enable = lib.mkEnableOption "Readarr Books Manager";
      package = mkPackageOption "readarr";
    };
    prowlarr = {
      enable = lib.mkEnableOption "Prowlarr Indexer Proxy";
      package = mkPackageOption "prowlarr";
    };
    sabnzbd = {
      enable = lib.mkEnableOption "SABnzbd Usenet Downloader";
      package = mkPackageOption "sabnzbd";
      # SABnzbd Usenet-Provider (wurde vergessen!)
      serverCredentialFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Pfad zur systemd-credential-Datei (.cred) mit Usenet-Server-Credentials.
          Format der entschlüsselten Datei:
            HOST=news.provider.com
            PORT=563
            USER=meinuser
            PASS=meinpasswort
            SSL=1
          Erfordert: systemd-creds encrypt --with-key=tpm2+host (siehe ONBOARDING.md).
        '';
      };
    };
    audiobookshelf = {
      enable = lib.mkEnableOption "Audiobookshelf Server";
      package = mkPackageOption "audiobookshelf";
      enableQuickSync = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          NOTE (misnomer): enableQuickSync benennt Intel QSV Transcode-Mapping.
          In mediNix-core zeigt dies korrekt auf Audiobookshelf-Hardware-Zugriff,
          NICHT auf Jellyfin (ursprünglicher Fehler im Quell-Repo, hier korrigiert).
        '';
      };
    };
    navidrome = {
      enable = lib.mkEnableOption "Navidrome Music Server";
      package = mkPackageOption "navidrome";
    };
    lidarr = {
      enable = lib.mkEnableOption "Lidarr Music Download Manager";
      package = mkPackageOption "lidarr";
    };
    exporters = {
      enable = lib.mkEnableOption "Prometheus exporters for Arr stack";
      lidarr.enable = lib.mkEnableOption "Enable metrics exporter for Lidarr";
    };
    mover = {
      enable = lib.mkEnableOption "ondemand Tier-B→Tier-C Mover (move media to HDD when SSD low)";
      mode = lib.mkOption {
        type = lib.types.enum [
          "ondemand"
          "off"
        ];
        default = "ondemand";
        description = ''
          "ondemand": Mover läuft nur bei Bedarf (Füllstand-Check im oneshot + systemd.path-Klingel).
          Kein Calendar-Timer als Haupttaktgeber — HDD soll schlafen dürfen.
          "off": Mover komplett inaktiv.
        '';
      };
      minFreeGb = lib.mkOption {
        type = lib.types.int;
        default = 20;
        description = ''
          Freier Platz auf stagingDir (Tier-B/SSD) in GB unterhalb dessen der Mover auslöst.
          Nur relevant wenn mode = "ondemand".
        '';
      };
      mediaExtensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          ".mkv"
          ".mp4"
          ".m4b"
          ".mp3"
          ".flac"
          ".webm"
          ".ts"
        ];
        description = ''
          Whitelist: nur Dateien mit diesen Endungen werden nach archiveDir (Tier-C/HDD) verschoben.
          Metadaten (NFO/JPG/Poster/DB) bleiben auf der SSD-Arbeitsseite.
        '';
      };
      stagingDir = lib.mkOption {
        type = lib.types.path;
        default = cfg.storage.backends.hot or (cfg.storage.mediaRoot + "/downloads");
        description = ''
          Quell-Pfad auf Tier-B (SSD): physisches Hot-Backend oder Staging-Verzeichnis.
          Wenn storage.backends.hot gesetzt ist, zeigt dies direkt auf das physische SSD-Backend,
          um innerhalb von MergerFS transparent von HOT nach COLD zu tierieren.
        '';
      };
      archiveDir = lib.mkOption {
        type = lib.types.path;
        default = cfg.storage.backends.cold or (cfg.storage.mediaRoot + "/library");
        description = ''
          Ziel-Pfad auf Tier-C (HDD): physisches Cold-Backend oder Archiv-Verzeichnis.
          Wenn storage.backends.cold gesetzt ist, zeigt dies direkt auf das physische HDD-Backend.
        '';
      };
      action = lib.mkOption {
        type = lib.types.enum [ "move" ];
        default = "move";
        description = ''
          "move": Datei nach HDD verschieben, SSD wird frei (Hardlink SSD↔HDD unmöglich — cross-device).
        '';
      };
    };
    feishin = {
      enable = lib.mkEnableOption "Feishin SPA (static files)";
      package = mkPackageOption "feishin";
    };
    pocketId = {
      enable = lib.mkEnableOption "Pocket ID OIDC Provider";
      package = mkPackageOption "pocket-id";
    };
    usenet-confinement.enable = lib.mkEnableOption "Run Usenet stack (SABnzbd/Prowlarr) isolated under WireGuard VPN interface";

    maintenance = {
      recyclarr = {
        enable = lib.mkEnableOption "Recyclarr custom format synchronization";
        package = mkPackageOption "recyclarr";
        schedule = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "Systemd calendar interval for Recyclarr runs.";
        };
      };
      updateNotifier = {
        enable = lib.mkEnableOption "Daily check for mediNix-core updates (ntfy notify, NO auto-update)";
      };
      provisioning = {
        enable = lib.mkEnableOption "API-Provisioning (register SABnzbd/Prowlarr/Root-Folders in *arr)";
        force = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Ignoriert das provisioned-Flag und laeuft trotzdem (einmalig).";
        };
        enforce = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Wenn true, wird der Nix-Sollzustand bei jedem Start erzwungen (ueberschreibt GUI-Aenderungen). Default false = GUI hat Vorrang.";
        };
      };
      backup = {
        enable = lib.mkEnableOption "Restic-Backup mit DB-Safety (stoppt Dienste vor Backup)";
        repository = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Restic repository (local path, sftp:, s3:, rclone:<remote>:, ...). Host-Config.";
        };
        passwordFile = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            Legacy: plain filesystem path to the restic password file. Used only when
            passwordCredentialPath is null. For a new setup prefer passwordCredentialPath
            (systemd-creds, Fail-Closed) -- see ADR-576-backup-classification.
          '';
        };
        passwordCredentialPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Empfohlen: Pfad zu einem TPM-versiegelten Restic-Passwort-Credential,
            erzeugt via systemd-creds encrypt (z.B.
            57-maintenance/medinix-seal-secret.sh restic-password '<pw>'
            -> /var/lib/medinix/secrets/restic-password.encrypted). Wird via
            LoadCredentialEncrypted eingebunden, das Klartext-Passwort landet nie
            auf Platte. Wenn gesetzt, wird passwordFile ignoriert. Siehe ADR-576-backup-classification.
          '';
        };
        schedule = lib.mkOption {
          type = lib.types.str;
          default = "02:00";
          description = "systemd OnCalendar for backup timer.";
        };
        offsite = {
          enable = lib.mkEnableOption ''
            Zweite Restic-Kopie (3-2-1: physisch/logisch getrenntes Ziel, z.B.
            Koofr-WebDAV via rclone oder eine zweite externe Platte). Laeuft per
            restic copy NACH einem erfolgreichen lokalen Backup -- kein zweiter
            Service-Stop noetig. ADR-576-backup-classification.
          '';
          repository = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Zweites Restic-Repository (z.B. rclone:koofr:mediNix-backup, oder Pfad auf einer zweiten externen Platte). Host-Config.";
          };
          passwordFile = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Legacy: siehe maintenance.backup.passwordFile, gilt fuer das Offsite-Repo.";
          };
          passwordCredentialPath = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Empfohlen: siehe maintenance.backup.passwordCredentialPath, gilt fuer das Offsite-Repo.";
          };
          rcloneConfigFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "rclone.conf, falls offsite.repository mit rclone: beginnt (z.B. Koofr WebDAV remote).";
          };
        };
      };
      sqliteOptimize = {
        enable = lib.mkEnableOption "Periodisches SQLite optimize/ANALYZE für Arr/SABnzbd/Jellyfin";
        schedule = lib.mkOption {
          type = lib.types.str;
          default = "04:00";
          description = "systemd OnCalendar for heavy TRUNCATE timer (default: 04:00).";
        };
        services = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "sonarr"
            "radarr"
            "prowlarr"
            "lidarr"
            "readarr"
            "sabnzbd"
            "jellyfin"
          ];
          description = "SQLite-Nutzer deren DBs optimiert werden (Registry-Namen).";
        };
      };
      orphanCleanup = {
        enable = lib.mkEnableOption "Orphan/Incomplete Cleanup (SABnzbd incomplete + verwaiste Fragmente)";
        schedule = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar for cleanup timer (default: daily).";
        };
        minAgeDays = lib.mkOption {
          type = lib.types.int;
          default = 7;
          description = "Mindestalter (Tage) bevor incomplete/Fragmente gelöscht werden.";
        };
      };
    };

    authProxyPresent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        true = Forward-Auth-Proxy (oauth2-proxy, Pocket-ID, Authentik) aktiv.
        Dann AUTH__METHOD=External für *arr. false = Forms-Auth.
        NIEMALS true ohne echten Proxy (Fail-Open-Risk).
      '';
    };

    # --- Chameleon Ingress ---
    ingress = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Caddy ingress mapping (reverse proxying).";
      };
      trustedCidrs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "192.168.2.0/24"
          "fd42:1234:5678::/64"
        ];
        description = ''
          Trust boundary: only these CIDRs may reach internal vhosts and the
          `.local` sites. Deliberately has NO broad default (10/8, 192.168/16,
          CGNAT) — set your real LAN CIDR(s). Enabling any vhost with an empty
          trustedCidrs is a build error (fail-closed, no implicit LAN trust).
        '';
      };
      vhosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              accessGroup = lib.mkOption {
                type = lib.types.enum [
                  "stream"
                  "internal"
                  "public"
                  "idp"
                  "none"
                ];
              };
              customConfig = lib.mkOption {
                type = lib.types.lines;
                default = "";
              };
              allowUnauthenticated = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Explicitly acknowledge an intentionally unauthenticated public
                  vhost. Without it, `accessGroup = "public"` while
                  ingress.auth.mode != "forward-auth" is a build error, and a
                  public vhost carrying unauthenticatedPaths needs it too.
                '';
              };
              localBypass = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
                description = ''
                  Per-vhost override for ingress.auth.localBypass (null = inherit).
                  When true, http://{service}.local skips forward_auth (still
                  CIDR-gated). Set only where the app login is authoritative.
                '';
              };
              unauthenticatedPaths = lib.mkOption {
                # Caddy path matchers must start with `/` and a whitespace would
                # split into MULTIPLE matchers (silently widening the bypass).
                # Quotes/braces would break Caddy tokenization.
                type = lib.types.listOf (lib.types.strMatching "^/[^ \t\"{}]*$");
                default = [ ];
                description = ''
                  Paths exempt from forward_auth (Caddy `@needAuth not path …`).
                  This is an AUTHENTICATION BYPASS list — the name is deliberate.
                  Each entry must start with `/`, use `*` for prefixes, and carry
                  no whitespace/quotes/braces. Merged with the global option.
                '';
              };
              landing = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Show this service on the 518 family page (organ of 511).";
              };
              iconSvg = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = "Inline SVG for the 518 tile. Declared next to the service, not in 518.";
              };
            };
          }
        );
        default = { };
        description = "Per-service Caddy vhost configuration.";
      };
      guardrails = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Build-time assertions (519) that keep the ingress on the mediNix path:
            no nginx/httpd/iptables/fail2ban; Caddy and the firewall stay on.
            Disable to opt out of the opinionated defaults entirely.
          '';
        };
        allow = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "nginx" ];
          description = ''
            Names exempted from the 519 guardrails (e.g. "nginx"). Each entry
            silences exactly one assertion — the escape hatch the message points to.
          '';
        };
      };
      mode = lib.mkOption {
        type = lib.types.enum [
          "auto"
          "global"
          "standalone"
        ];
        default = "auto";
        description = ''
          auto: Hook into global caddy if config.services.caddy.enable, else standalone.
          global: Force injection into global Caddy.
          standalone: Force standalone caddy-media on port 80/443.
        '';
      };
      tls = {
        mode = lib.mkOption {
          type = lib.types.enum [
            "off"
            "internal"
            "custom"
          ];
          default = "off";
          description = ''
            off: HTTP :80 only — unless tls.acmeHost is set, which always enables
            HTTPS with the Lego wildcard (514). Caddy never issues certificates.
            internal: HTTP :80 + HTTPS :443 (Caddy internal CA, devices must trust it).
            custom: HTTPS :443 with certFile + keyFile.
          '';
        };
        certFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/var/lib/acme/example.com/cert.pem";
        };
        keyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/var/lib/acme/example.com/key.pem";
        };
        # TLS via security.acme (Lego, DNS-01 via Cloudflare) — flake-managed.
        # 514-acme.nix konfiguriert security.acme wenn acmeHost != null.
        acmeHost = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "example.com";
          description = ''
            Hostname for the security.acme certificate (apex + wildcard *.acmeHost).
            When set: 514 issues via Lego DNS-01 (Cloudflare); 511 attaches
            fullchain.pem + key.pem to every https://{name}.{domain} vHost — including
            LAN-only services (internal abort). This is the HTTPS-on-LAN path.
            Let's Encrypt cannot sign .local; http://{name}.local stays HTTP.
            Requires ingress.tls.acmeCredential (its own token, Lego DNS-01).
          '';
        };
        # Dedizierter ACME-Token (Lego), unabhaengig vom DDNS-Token.
        acmeCredential = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/var/lib/credstore.encrypted/cf-acme-token.cred";
          description = ''
            TPM-sealed .cred for the Cloudflare token used by Lego (ACME DNS-01)
            ONLY — loaded into acme-<acmeHost>.service via LoadCredentialEncrypted.
            Content format: CF_DNS_API_TOKEN=<token>
            Required when ingress.tls.acmeHost is set. Must be a DIFFERENT token
            than dns.ddns.cloudflareTokenCredential. Scope: Zone:DNS:Edit on
            exactly the acme zone (TXT _acme-challenge).
          '';
        };
      };
      auth = {
        mode = lib.mkOption {
          type = lib.types.enum [
            "none"
            "forward-auth"
          ];
          default = "none";
        };
        forwardAuthUpstream = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "http://127.0.0.1:4180";
        };
        forwardAuthUri = lib.mkOption {
          type = lib.types.str;
          default = "/oauth2/auth";
        };
        unauthenticatedPaths = lib.mkOption {
          type = lib.types.listOf (lib.types.strMatching "^/[^ \t\"{}]*$");
          default = [ ];
          example = [
            "/metrics"
            "/health"
          ];
          description = ''
            Global authentication-bypass list, merged into every vhost's
            unauthenticatedPaths. Prefer the per-vhost option. Any path listed
            here is reachable WITHOUT forward_auth. Entries must start with `/`,
            use `*` for prefixes, and carry no whitespace/quotes/braces.
          '';
        };
        localBypass = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Default for vhosts.localBypass. false means http://{service}.local
            is still CIDR-gated AND authenticated (when auth.mode =
            "forward-auth"). .local is a hostname, not a trust boundary: a
            compromised LAN host can send Host: {service}.local. Enable the
            bypass explicitly per vhost where the app login is authoritative.
          '';
        };
      };
      landing = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Family icon page served by 511 on https://{domain} (LAN-only abort)
            and http://home.local. Built by 518 from stream/public vhosts.
          '';
        };
        root = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          internal = true;
          description = "Nix store path with index.html; set by 518-landingpage.nix.";
        };
      };
    };

    # --- Security (guardrails) ---
    security = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable mediNix security guardrails (assertions, no-password-auth).";
      };
      emergencyUser = {
        enable = lib.mkEnableOption "media-admin emergency user (restricted sudo)";
        sshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys for media-admin user.";
        };
        allowedServices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "caddy-media"
            "pocket-id"
          ];
          description = ''
            EXACT units media-admin may `systemctl restart`. Deliberately NOT
            "all registry services": the privileged surface is explicit and
            reviewable, and does not grow when the registry grows. Must be
            non-empty when enable = true; every entry must exist in the
            registry (otherwise a build error).
          '';
        };
      };
      backupSsh = {
        enable = lib.mkEnableOption "read-only backup SSH user (rsync pull of State-Dirs)";
        sshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys for backup user.";
        };
      };
    };

    knownStateDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Auto-generated list of all state directories for orphan detection";
    };

    factoryUnits = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            uid = lib.mkOption { type = lib.types.int; };
            stateDir = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      default = { };
      internal = true;
      description = ''
        Units actually created by lib/service-factory.nix, keyed by the real unit
        name. The ADR-5050 guardrail (591) verifies these — not the registry
        names, which would wrongly assume unit name == registry key (the
        standalone reverse proxy is `caddy-media`, not `caddy`).
      '';
    };
    # --- Observability (Notifications) ---
    observability = {
      ntfy = {
        enable = lib.mkEnableOption "ntfy.sh push notifications for Arr stack + Jellyfin";
        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://ntfy.sh";
          description = ''
            ntfy server URL. Default ntfy.sh (free, no self-host) oder
            self-hosted (services.ntfy-sh auf Port 5810, caddyClass=public).
          '';
        };
        topic = lib.mkOption {
          type = lib.types.str;
          default = "mediNix";
          description = "ntfy topic name for mediNix notifications.";
        };
      };
      crowdsec = {
        enable = lib.mkEnableOption "CrowdSec native WAF/IPS agent (no Docker)";
        enrollKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Path to CrowdSec enrollment token file (LoadCredentialEncrypted).
            Wenn null: lokaler Standalone-Modus (kein Central-Sync).
          '';
        };
      };
      runtimeGuard = lib.mkEnableOption "Stündlicher Runtime-Check (nftables/0.0.0.0-bind/VPN-Interface) via ntfy";
      driftDetection = lib.mkEnableOption "30-Min-Ticker: State-Dir-Permissions + Tier-Mounts via ntfy";
      postBootWatchdog = lib.mkEnableOption "Einmalig 180s nach Boot: failed Services neustarten via ntfy";
    };

    # --- DNS ---
    dns = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "host"
          "standalone"
        ];
        default = "host";
        description = ''
          host: Modul liefert nur Tier-Listen + vHost-Namen. DDNS/ACME macht Host.
          standalone: 513 hält die Anker wan (WAN-IP) und lan (LAN-IP) plus
          Wildcard/Apex-CNAME auf wan. Keine per-service CNAMEs.
        '';
      };
      hostnames = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          feishin = "music";
        };
        description = ''
          Extra public hostname for a registry service. 511 serves the same
          template on {alias}.{domain}; 513 prunes leftover CNAMEs for both names.
          Example: feishin = "music" → https://music.example.com
        '';
      };
      ddns = {
        enable = lib.mkEnableOption "Eigener dynamischer DNS-Sync (standalone only)";
        zone = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "example.com";
        };
        interval = lib.mkOption {
          type = lib.types.str;
          default = "5m";
        };
        # Cloudflare token for DDNS (513) — TPM-cred workflow. NOT for ACME.
        cloudflareTokenCredential = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Path to the TPM-sealed .cred for the Cloudflare API token used by
            513 DDNS ONLY (records + prune). Required when DDNS is enabled.
            Must be a DIFFERENT token than ingress.tls.acmeCredential.
            Scope: Zone:DNS:Edit on exactly the DDNS zone.
          '';
        };
        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/run/secrets/cloudflare_ddns_token";
        };
      };
    };

    # --- Declarative Ports (SSoT from registry) ---
    ports = lib.mapAttrs (
      name: default:
      lib.mkOption {
        type = lib.types.port;
        inherit default;
        description = "Port für ${name}. Abgeleitet: Num × 10 (ADR-5043).";
      }
    ) (import ./lib/registry.nix { inherit lib; }).ports;

    # --- Hardware ---
    hardware = {
      ramGB = lib.mkOption {
        type = lib.types.int;
        default = 16;
      };
      accel = lib.mkOption {
        type = lib.types.enum [
          "auto"
          "intel"
          "amd"
          "nvidia"
          "vaapi"
          "none"
        ];
        default = "auto";
        description = ''
          Hardwarebeschleunigung für Transkodierung. Eine Angabe → DeviceAllow,
          Pakete, Gruppen, ffmpeg-Methode. auto leitet aus Host-Config ab.
        '';
      };
      renderDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/dev/dri/renderD129";
      };
    };

    locale = {
      language = lib.mkOption {
        type = lib.types.str;
        default = "en";
      };
      default = lib.mkOption {
        type = lib.types.str;
        default = "en_US.UTF-8";
      };
    };

    storage = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      mediaRoot = lib.mkOption {
        type = lib.types.path;
        default = "/data";
        description = "Base directory for media storage downloads/library.";
      };
      metadataDir = lib.mkOption {
        type = lib.types.path;
        default =
          if cfg.storage.backends ? hot then
            cfg.storage.backends.hot + "/cache"
          else
            "/var/lib/media-metadata";
        description = "Base directory for heavy metadata artwork stores.";
      };
      offloadMediaCover = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Offload MediaCover image caches from /var/lib/{arr}/MediaCover to storage.metadataDir via systemd BindPaths.
          Enforces 'State != Cache' principle to keep backups of /var/lib minimal and prevent SSD wear.
        '';
      };
      backends = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          hot = "/mnt/ssd";
          cold = "/mnt/hdd";
        };
        description = ''
          Storage-Backends für Multi-Tier-Betrieb (ADR-5710).
          Leer (Default) = einfacher Modus: nur mediaRoot, kein MergerFS.
          hot + cold: Flake erstellt MergerFS-Pools für jeden Medientyp automatisch.
          Erwartete Schlüssel: hot (SSD/NVMe), cold (HDD). Optional: media (mittleres Tier).
          Host-Pflicht: Physische Mounts (fileSystems."/mnt/ssd" etc.) im Host anlegen.
          Nur die Zuordnung hot=/mnt/ssd; cold=/mnt/hdd kommt hierher.
        '';
      };
    };

    diskHealth = {
      enable = lib.mkEnableOption "SMART disk health monitoring via smartd with standby preservation";
      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "DEVICESCAN" ];
        example = [ "/dev/disk/by-id/ata-WDC_WD40EFRX-68N32N0_WD-WCC7K..." ];
        description = ''
          Disks for smartd to monitor. Defaults to DEVICESCAN.
          To target specific mechanical HDDs or avoid scanning virtual/SSD devices,
          specify persistent /dev/disk/by-id/ or /dev/disk/by-label/ device paths.
        '';
      };
      spindownPreservation = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Append '-n standby,q' to smartd checks.
          Ensures smartd NEVER wakes up spun-down mechanical hard drives from standby.
        '';
      };
      notifyNtfy = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Send SMART failure alerts to internal ntfy (port 5810).";
      };
    };

    onDemand = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      internalOffset = lib.mkOption {
        type = lib.types.int;
        default = 1000;
      };
      idleTimeoutSec = lib.mkOption {
        type = lib.types.int;
        default = 900;
      };
    };

    discovery = {
      mdns = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };
    };

    vpn = {
      enable = lib.mkEnableOption "Flake-managed WireGuard VPN (mediNix erstellt das Interface selbst)";

      interface = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "wg0";
        description = ''
          Effektiver Interface-Name (für Killswitch + Confinement).
          Wenn vpn.enable = true && vpn.useExistingInterface = false:
            → wird automatisch auf vpn.interfaceName gesetzt (via 526-vpn-interface.nix).
          Wenn vpn.useExistingInterface = true:
            → muss manuell auf das Host-Interface gesetzt werden (Legacy-Modus).
          Leer (default) = kein confinement, auch wenn usenet-confinement.enable.
        '';
      };

      interfaceName = lib.mkOption {
        type = lib.types.str;
        default = "wg-medinix";
        description = "Name des WireGuard-Interfaces das mediNix selbst anlegt (vpn.enable = true). Wird als networking.wireguard.interfaces.<interfaceName> registriert.";
      };

      address = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "10.64.0.2/32" ];
        description = "IP-Adressen (CIDR) des WireGuard-Interfaces.";
      };

      dns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "10.64.0.1" ];
        description = ''
          DNS-Server für das WireGuard-Interface (DNS-Leak-Schutz).
          Werden auch in dnsServers gespiegelt (Killswitch-Compat).
        '';
      };

      peer = {
        publicKey = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "WireGuard Public Key des VPN-Peers.";
        };
        endpoint = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "vpn.provider.com:51820";
          description = "Endpunkt des VPN-Peers (host:port).";
        };
        allowedIPs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "0.0.0.0/0"
            "::/0"
          ];
          description = "AllowedIPs für den VPN-Peer (Default: Full-Tunnel).";
        };
        persistentKeepalive = lib.mkOption {
          type = lib.types.int;
          default = 25;
          description = "PersistentKeepalive in Sekunden.";
        };
      };

      privateKeyCredentialPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/var/lib/credstore.encrypted/wg-private-key.cred";
        description = ''
          Pfad zur TPM-sealed .cred-Datei (systemd-creds encrypt --with-key=tpm2+host).
          Wird als LoadCredentialEncrypted in wireguard-<interfaceName>.service geladen.
          Zur Laufzeit unter /run/credentials/wireguard-<interfaceName>.service/wg-private-key
          verfügbar (als privateKeyFile für das WireGuard-Interface).
          Nur benötigt wenn vpn.enable = true und vpn.useExistingInterface = false.
        '';
      };

      useExistingInterface = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          false (Default): mediNix erstellt das WireGuard-Interface selbst (flake-first).
          true: mediNix nutzt ein vom Host vorbereitetes Interface (vpn.interface muss gesetzt sein).
          Escape-Hatch für Spezialsetups oder schrittweise Migration vom Legacy-Modus.
        '';
      };

      dnsServers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ]; # Fail-Closed: Keine automatischen Public-DNS Fallbacks
        example = [ "10.8.0.1" ];
        description = ''
          DNS-Server für Usenet-Sandbox (VPN-DNS). LEER default (kein stiller Public-DNS).
          Wenn vpn.enable = true: automatisch aus vpn.dns befüllt (mkDefault).
          Assertion erzwingt explizite Setzung bei usenet-confinement.enable.
          Für encrypted DNS: lokale Stubs (stubby/cloudflared/nextdns) eintragen.
          Siehe ADMIN-HANDOFF §4a.
        '';
      };
    };

    secrets = {
      secretsDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/media-secrets";
        description = "Base path for all internal and generated secrets.";
      };
      arrApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.secrets.secretsDir}/arr-apikey";
      };
      sonarrApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = cfg.secrets.arrApiKeyFile;
      };
      radarrApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = cfg.secrets.arrApiKeyFile;
      };
      prowlarrApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = cfg.secrets.arrApiKeyFile;
      };
      lidarrApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = cfg.secrets.arrApiKeyFile;
      };
      readarrApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = cfg.secrets.arrApiKeyFile;
      };
      seerrApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.secrets.secretsDir}/seerr_api_key";
      };
      sabnzbdApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.secrets.secretsDir}/sabnzbd_api_key";
      };
      treasureMapsApiKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.secrets.secretsDir}/treasuremaps_api_key";
        description = "API key for the treasure-maps.com Newznab indexer, registered in Prowlarr.";
      };
      jellyfinAdminPasswordFile = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.secrets.secretsDir}/jellyfin_admin_password";
      };
      navidromeOidcFile = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.secrets.secretsDir}/navidrome-oidc.env";
      };
      seerrEnvFile = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.secrets.secretsDir}/seerr.env";
      };
      autoGenerate = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Generate shared Arr API key + per-service env at boot.";
      };
    };

    persist = {
      enable = lib.mkEnableOption "Hook state paths into local impermanence bindings";
      extraPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = {
      gid = 5000;
    };

    # Binary-Cache defaults — flake-first: nothing gets compiled on the media host.
    # mkDefault allows the host to extend or override the list without conflict.
    nix.settings = {
      substituters = lib.mkDefault [
        "https://cache.nixos.org"
      ];
      trusted-public-keys = lib.mkDefault [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    # mediNix Health CLI (Build-Zeit aus Registry generiert)
    environment.systemPackages = lib.mkIf cfg.cli.enable [
      (pkgs.callPackage ./lib/cli.nix {
        inherit lib;
        registryJson = builtins.toJSON (import ./lib/registry.nix { inherit lib; }).services;
        mediaRoot = cfg.storage.mediaRoot;
        metadataDir = cfg.storage.metadataDir;
        mediaDomain = cfg.domain or "";
      })
    ];
  };
}
