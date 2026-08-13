# ---
# id: "50-mediNix-default"
# title: "mediNix Master Boilerplate (SSoT, auto-imports all decades)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 5
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
# provides: ["options.grapefruitMedia"]
# requires: ["lib/registry", "lib/service-factory"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
# 50-mediNix Master Boilerplate (SSoT)
#
# Portable module entrypoint. Auto-imports every XX-domain/NNN-*.nix module
# (flat structure, ADR-0000 §9). No hardcoded import list.
#
# Options API ported from grapefruit89/mediNix (709-line default.nix), made
# portable: no my.* references, all paths/domains via options (Regel 3).
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia;

  # Helper: optional package override (null = nixpkgs default)
  mkPackageOption = svc: lib.mkOption {
    type        = lib.types.nullOr lib.types.package;
    default     = null;
    defaultText = lib.literalExpression "null";
    description = ''
      Optionales Paket-Override für ${svc}.
      null = NixOS-Modul-Default aus nixpkgs.
    '';
  };

  # Auto-import: every XX-domain/NNN-*.nix module (lib.pipe für Idiomatik)
  moduleFiles =
    let
      entries     = builtins.readDir ./.;
      isModuleDir = n: t: t == "directory" && builtins.match "^[0-9]{2}-.*" n != null;
      importFromDir = dir:
        let
          files = builtins.readDir (./. + "/${dir}");
        in
        map (n: ./. + "/${dir}/${n}")
          (builtins.attrNames (lib.filterAttrs
            (n: t: t == "regular" && builtins.match "^[0-9]{3}-.*\\.nix$" n != null)
            files));
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

  options.grapefruitMedia = {
    enable = lib.mkEnableOption "Standalone Media Stack Module";

    cli = {
      enable = lib.mkOption {
        type    = lib.types.bool;
        default = true;
        description = "medinix CLI-Tool installieren (check/repair/status/vpn/secrets).";
      };
    };

    domain = lib.mkOption {
      type    = lib.types.nullOr lib.types.str;
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
      enable  = lib.mkEnableOption "Jellyfin Media Server";
      package = mkPackageOption "jellyfin";
      adminPasswordFile = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
        description = ''Pfad zur verschlüsselten Admin-Passwort-Datei (systemd-creds encrypt).
          ADR-5510: Jellyfin speichert First-Run-Status in DB (nicht Config) — Passwort
          MUSS vor dem ersten Start da sein (LoadCredentialEncrypted). Ohne: Web-UI blockiert.'';
      };
      # Jellyfin Admin (First-Run Bootstrap) — TPM-cred Workflow
      adminPasswordCredential = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Pfad zur .cred-Datei (systemd-creds TPM-verschlüsselt) für Jellyfin Admin-Passwort.
          Wird via LoadCredentialEncrypted als mediNix-jellyfin-admin gemountet.
        '';
      };
    };
    jellyseerr = {
      enable  = lib.mkEnableOption "Jellyseerr Request Manager";
      package = mkPackageOption "jellyseerr";
    };
    bazarr = {
      enable  = lib.mkEnableOption "Bazarr Subtitle Downloader (Sonarr/Radarr)";
      package = mkPackageOption "bazarr";
    };
    sonarr = {
      enable  = lib.mkEnableOption "Sonarr TV Series Manager";
      package = mkPackageOption "sonarr";
      rootFolder     = lib.mkOption { type = lib.types.str;  default = cfg.storage.mediaRoot + "/tv";     description = "Arr root folder (API-configured via provisioning)."; };
      qualityProfile = lib.mkOption { type = lib.types.str;  default = "HD-1080p";                       description = "Arr quality profile name (API-configured via provisioning)."; };
    };
    radarr = {
      enable  = lib.mkEnableOption "Radarr Movies Manager";
      package = mkPackageOption "radarr";
      rootFolder     = lib.mkOption { type = lib.types.str;  default = cfg.storage.mediaRoot + "/movies"; description = "Arr root folder (API-configured via provisioning)."; };
      qualityProfile = lib.mkOption { type = lib.types.str;  default = "HD-1080p";                        description = "Arr quality profile name (API-configured via provisioning)."; };
    };
    readarr = {
      enable  = lib.mkEnableOption "Readarr Books Manager";
      package = mkPackageOption "readarr";
    };
    prowlarr = {
      enable  = lib.mkEnableOption "Prowlarr Indexer Proxy";
      package = mkPackageOption "prowlarr";
    };
    sabnzbd = {
      enable  = lib.mkEnableOption "SABnzbd Usenet Downloader";
      package = mkPackageOption "sabnzbd";
      # SABnzbd Usenet-Provider (wurde vergessen!)
      serverCredentialFile = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
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
      enable  = lib.mkEnableOption "Audiobookshelf Server";
      package = mkPackageOption "audiobookshelf";
      enableQuickSync = lib.mkOption {
        type        = lib.types.bool;
        default     = true;
        description = ''
          NOTE (misnomer): enableQuickSync benennt Intel QSV Transcode-Mapping.
          In mediNix-core zeigt dies korrekt auf Audiobookshelf-Hardware-Zugriff,
          NICHT auf Jellyfin (ursprünglicher Fehler im Quell-Repo, hier korrigiert).
        '';
      };
    };
    navidrome = {
      enable  = lib.mkEnableOption "Navidrome Music Server";
      package = mkPackageOption "navidrome";
    };
    lidarr = {
      enable  = lib.mkEnableOption "Lidarr Music Download Manager";
      package = mkPackageOption "lidarr";
    };
    recyclarr = {
      enable  = lib.mkEnableOption "Recyclarr custom format synchronization";
      package = mkPackageOption "recyclarr";
      schedule = lib.mkOption {
        type    = lib.types.str;
        default = "daily";
        description = "Systemd calendar interval for Recyclarr runs.";
      };
    };
    exporters = {
      enable           = lib.mkEnableOption "Prometheus exporters for Arr stack";
      lidarr.enable    = lib.mkEnableOption "Enable metrics exporter for Lidarr";
    };
    mover = {
      enable = lib.mkEnableOption "Tier-B cleanup (remove already-imported downloads)";
      retentionDays = lib.mkOption {
        type    = lib.types.int;
        default = 7;
        description = ''
          Anzahl Tage nach denen importierte Downloads auf Tier B (SSD) gelöscht
          werden. Sonarr/Radarr importieren selbst (Tier B -> Tier C HDD).
          Hardlinks SSD<->HDD unmöglich -> Copy, daher Tier B hier aufräumen.
        '';
      };
    };
    updateNotifier = {
      enable = lib.mkEnableOption "Daily check for mediNix-core updates (ntfy notify, NO auto-update)";
    };
    feishin = {
      enable  = lib.mkEnableOption "Feishin SPA (static files)";
      package = mkPackageOption "feishin";
    };
    pocketId = {
      enable  = lib.mkEnableOption "Pocket ID OIDC Provider";
      package = mkPackageOption "pocket-id";
    };
    usenet-confinement.enable = lib.mkEnableOption
      "Run Usenet stack (SABnzbd/Prowlarr) isolated under WireGuard VPN interface";

    maintenance = {
      provisioning = {
        enable = lib.mkEnableOption "API-Provisioning (register SABnzbd/Prowlarr/Root-Folders in *arr)";
      };
      backup = {
        enable = lib.mkEnableOption "Restic-Backup mit DB-Safety (stoppt Dienste vor Backup)";
        repository = lib.mkOption {
          type    = lib.types.str;
          default = "";
          description = "Restic repository (local path, sftp:, s3:, ...). Host-Config.";
        };
        passwordFile = lib.mkOption {
          type    = lib.types.str;
          default = "";
          description = "Path to restic password file (LoadCredentialEncrypted).";
        };
        schedule = lib.mkOption {
          type    = lib.types.str;
          default = "02:00";
          description = "systemd OnCalendar for backup timer.";
        };
      };
      sqliteOptimize = {
        enable = lib.mkEnableOption "Periodisches SQLite optimize/ANALYZE für Arr/SABnzbd/Jellyfin";
        schedule = lib.mkOption {
          type    = lib.types.str;
          default = "weekly";
          description = "systemd OnCalendar for optimize timer (default: weekly).";
        };
        services = lib.mkOption {
          type    = lib.types.listOf lib.types.str;
          default = [ "sonarr" "radarr" "prowlarr" "lidarr" "readarr" "sabnzbd" "jellyfin" ];
          description = "SQLite-Nutzer deren DBs optimiert werden (Registry-Namen).";
        };
      };
      orphanCleanup = {
        enable = lib.mkEnableOption "Orphan/Incomplete Cleanup (SABnzbd incomplete + verwaiste Fragmente)";
        schedule = lib.mkOption {
          type    = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar for cleanup timer (default: daily).";
        };
        minAgeDays = lib.mkOption {
          type    = lib.types.int;
          default = 7;
          description = "Mindestalter (Tage) bevor incomplete/Fragmente gelöscht werden.";
        };
      };
    };

    authProxyPresent = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = ''
        true = Forward-Auth-Proxy (oauth2-proxy, Pocket-ID, Authentik) aktiv.
        Dann AUTH__METHOD=External für *arr. false = Forms-Auth.
        NIEMALS true ohne echten Proxy (Fail-Open-Risk).
      '';
    };

    # --- Chameleon Ingress ---
    ingress = {
      enable = lib.mkOption {
        type    = lib.types.bool;
        default = true;
        description = "Enable Caddy ingress mapping (reverse proxying).";
      };
      mode = lib.mkOption {
        type    = lib.types.enum [ "auto" "global" "standalone" ];
        default = "auto";
        description = ''
          auto: Hook into global caddy if config.services.caddy.enable, else standalone.
          global: Force injection into global Caddy.
          standalone: Force standalone caddy-media on port 80/443.
        '';
      };
      tls = {
        mode = lib.mkOption {
          type    = lib.types.enum [ "off" "internal" "custom" ];
          default = "off";
          description = ''
            off: HTTP :80 only. internal: HTTP :80 + HTTPS :443 (Caddy CA).
            custom: HTTPS :443 with external cert (certFile + keyFile).
          '';
        };
        certFile = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
          default = null;
          example = "/var/lib/acme/example.com/cert.pem";
        };
        keyFile = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
          default = null;
          example = "/var/lib/acme/example.com/key.pem";
        };
        # TLS via security.acme (Lego, DNS-01 via Cloudflare) auf dem Host.
        # mediNix-core liest nur das fertige Zertifikat, macht KEIN ACME selbst.
        acmeHost = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
          default = null;
          example = "m7c5.de";
          description = ''
            Hostname des security.acme-Zertifikats auf dem Host.
            Wenn gesetzt: Caddy nutzt /var/lib/acme/{acmeHost}/cert.pem
            und /var/lib/acme/{acmeHost}/key.pem automatisch.
            Setzt tls.mode implizit auf "custom".
            security.acme wird vom Host konfiguriert (DNS-01 via Cloudflare),
            NICHT von mediNix-core. mediNix-core liest nur das fertige Zertifikat.
          '';
        };
      };
      auth = {
        mode = lib.mkOption {
          type    = lib.types.enum [ "none" "forward-auth" ];
          default = "none";
        };
        forwardAuthUpstream = lib.mkOption {
          type    = lib.types.str;
          default = "";
          example = "http://127.0.0.1:4180";
        };
        forwardAuthUri = lib.mkOption {
          type    = lib.types.str;
          default = "/oauth2/auth";
        };
        skipPaths = lib.mkOption {
          type    = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "/metrics" "/health" ];
        };
        localBypass = lib.mkOption {
          type    = lib.types.bool;
          default = true;
          description = ''
            L1 ({service}.local) ohne forward_auth, auch bei auth.mode=forward-auth.
            .local ist reines LAN (RFC 6762), physische Grenze = Sicherheitsgrenze.
          '';
        };
      };
    };

    # --- Security (guardrails) ---
    security = {
      enable = lib.mkOption {
        type    = lib.types.bool;
        default = true;
        description = "Enable mediNix security guardrails (assertions, no-password-auth).";
      };
      emergencyUser = {
        enable = lib.mkEnableOption "media-admin emergency user (restricted sudo)";
        sshKeys = lib.mkOption {
          type    = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys for media-admin user.";
        };
      };
      backupSsh = {
        enable = lib.mkEnableOption "read-only backup SSH user (rsync pull of State-Dirs)";
        sshKeys = lib.mkOption {
          type    = lib.types.listOf lib.types.str;
          default = [ ];
          description = "SSH public keys for backup user.";
        };
      };
    };

    # --- Observability (Notifications) ---
    observability = {
      ntfy = {
        enable = lib.mkEnableOption "ntfy.sh push notifications for Arr stack + Jellyfin";
        baseUrl = lib.mkOption {
          type    = lib.types.str;
          default = "https://ntfy.sh";
          description = ''
            ntfy server URL. Default ntfy.sh (free, no self-host) oder
            self-hosted (services.ntfy-sh auf Port 5810, caddyClass=public).
          '';
        };
        topic = lib.mkOption {
          type    = lib.types.str;
          default = "mediNix";
          description = "ntfy topic name for mediNix notifications.";
        };
      };
      crowdsec = {
        enable = lib.mkEnableOption "CrowdSec native WAF/IPS agent (no Docker)";
        enrollKeyFile = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
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
        type    = lib.types.enum [ "host" "standalone" ];
        default = "host";
        description = ''
          host: Modul liefert nur Tier-Listen + vHost-Namen. DDNS/ACME macht Host.
          standalone: Eigenes DDNS (513-cloudflare-dns.nix) dabei.
        '';
      };
      hostnames = lib.mkOption {
        type    = lib.types.attrsOf lib.types.str;
        default = { };
        example = { navidrome = "music"; };
      };
      ddns = {
        enable    = lib.mkEnableOption "Eigener dynamischer DNS-Sync (standalone only)";
        zone      = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
          default = null;
          example = "example.com";
        };
        interval  = lib.mkOption {
          type    = lib.types.str;
          default = "5m";
        };
        # Cloudflare Token (für DDNS + ACME) — TPM-cred Workflow
        cloudflareTokenCredential = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Pfad zur .cred-Datei (systemd-creds TPM-verschlüsselt) für Cloudflare API Token.
            Wird via LoadCredentialEncrypted als mediNix-cf-token gemountet.
            Erforderlich für DDNS + ACME (security.acme).
          '';
        };
        tokenCredential = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
          default = null;
          example = "/var/lib/credstore.encrypted/CF_DDNS_API_TOKEN.cred";
        };
        tokenFile = lib.mkOption {
          type    = lib.types.nullOr lib.types.str;
          default = null;
          example = "/run/secrets/cloudflare_ddns_token";
        };
      };
    };

    # --- Declarative Ports (SSoT from registry) ---
    ports = lib.mapAttrs
      (name: default: lib.mkOption {
        type        = lib.types.port;
        inherit default;
        description = "Port für ${name}. Abgeleitet: Num × 10 (ADR-5043).";
      })
      (import ./lib/registry.nix { inherit lib; }).ports;

    # --- Hardware ---
    hardware = {
      ramGB = lib.mkOption {
        type    = lib.types.int;
        default = 16;
      };
      accel = lib.mkOption {
        type    = lib.types.enum [ "auto" "intel" "amd" "nvidia" "vaapi" "none" ];
        default = "auto";
        description = ''
          Hardwarebeschleunigung für Transkodierung. Eine Angabe → DeviceAllow,
          Pakete, Gruppen, ffmpeg-Methode. auto leitet aus Host-Config ab.
        '';
      };
      renderDevice = lib.mkOption {
        type    = lib.types.nullOr lib.types.str;
        default = null;
        example = "/dev/dri/renderD129";
      };
    };

    locale = {
      language = lib.mkOption { type = lib.types.str; default = "en"; };
      default  = lib.mkOption { type = lib.types.str; default = "en_US.UTF-8"; };
    };

    storage = {
      enable     = lib.mkOption { type = lib.types.bool; default = true; };
      mediaRoot  = lib.mkOption {
        type        = lib.types.path;
        default     = "/data";
        description = "Base directory for media storage downloads/library.";
      };
      metadataDir = lib.mkOption {
        type        = lib.types.path;
        default     = "/var/lib/media-metadata";
        description = "Base directory for heavy metadata artwork stores.";
      };
    };

    onDemand = {
      enable         = lib.mkOption { type = lib.types.bool; default = false; };
      internalOffset = lib.mkOption { type = lib.types.int;  default = 1000; };
      idleTimeoutSec = lib.mkOption { type = lib.types.int;  default = 900; };
    };

    discovery = {
      mdns = {
        enable       = lib.mkOption { type = lib.types.bool; default = true; };
        openFirewall = lib.mkOption { type = lib.types.bool; default = true; };
      };
    };

    vpn = {
      interface = lib.mkOption {
        type    = lib.types.str;
        default = "";
        example = "privado";
        description = ''
          Name des WireGuard-Interfaces auf dem Host (z.B. "privado", "wg0").
          Das Interface muss vom Host-System bereitgestellt werden
          (systemd-networkd routeTables oder wg-quick).
          mediNix-core erstellt KEIN Interface — es nutzt es nur.
          Empfohlen: UID-basiertes Routing via systemd-networkd routeTables
          (siehe Nix-Grok modules/10-network/1096-vpn.nix als Referenz).
          Leer (default) = kein confinement, auch wenn usenet-confinement.enable.
        '';
      };
      dnsServers = lib.mkOption {
        type    = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "10.8.0.1" ];
        description = ''
          DNS-Server für Usenet-Sandbox (VPN-DNS). LEER default (kein stiller Public-DNS).
          Assertion erzwingt explizite Setzung bei usenet-confinement.enable.
        '';
      };
    };

    secrets = {
      secretsDir = lib.mkOption {
        type        = lib.types.str;
        default     = "/var/lib/media-secrets";
        description = "Base path for all internal and generated secrets.";
      };
      arrApiKeyFile = lib.mkOption {
        type    = lib.types.str;
        default = "${cfg.secrets.secretsDir}/arr-apikey";
      };
      sonarrApiKeyFile    = lib.mkOption { type = lib.types.str; default = cfg.secrets.arrApiKeyFile; };
      radarrApiKeyFile    = lib.mkOption { type = lib.types.str; default = cfg.secrets.arrApiKeyFile; };
      prowlarrApiKeyFile  = lib.mkOption { type = lib.types.str; default = cfg.secrets.arrApiKeyFile; };
      lidarrApiKeyFile    = lib.mkOption { type = lib.types.str; default = cfg.secrets.arrApiKeyFile; };
      readarrApiKeyFile   = lib.mkOption { type = lib.types.str; default = cfg.secrets.arrApiKeyFile; };
      jellyseerrApiKeyFile = lib.mkOption {
        type    = lib.types.str;
        default = "${cfg.secrets.secretsDir}/jellyseerr_api_key";
      };
      sabnzbdApiKeyFile = lib.mkOption {
        type    = lib.types.str;
        default = "${cfg.secrets.secretsDir}/sabnzbd_api_key";
      };
      jellyfinAdminPasswordFile = lib.mkOption {
        type    = lib.types.str;
        default = "${cfg.secrets.secretsDir}/jellyfin_admin_password";
      };
      navidromeOidcFile = lib.mkOption {
        type    = lib.types.str;
        default = "${cfg.secrets.secretsDir}/navidrome-oidc.env";
      };
      jellyseerrEnvFile = lib.mkOption {
        type    = lib.types.str;
        default = "${cfg.secrets.secretsDir}/jellyseerr.env";
      };
      autoGenerate = lib.mkOption {
        type        = lib.types.bool;
        default     = false;
        description = "Generate shared Arr API key + per-service env at boot.";
      };
    };

    persist = {
      enable     = lib.mkEnableOption "Hook state paths into local impermanence bindings";
      extraPaths = lib.mkOption {
        type    = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = { gid = 5000; };

    # mediNix Health CLI (Build-Zeit aus Registry generiert)
    environment.systemPackages = lib.mkIf cfg.cli.enable [
      (pkgs.callPackage ./packages/mediNix-cli {
        inherit lib;
        registryJson = builtins.toJSON (import ./lib/registry.nix { inherit lib; }).services;
        mediaRoot   = cfg.storage.mediaRoot;
        metadataDir = cfg.storage.metadataDir;
        mediaDomain = cfg.domain or "";
      })
    ];
  };
}
