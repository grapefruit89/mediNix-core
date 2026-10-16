# ---
# id: "551-jellyfin"
# title: "Jellyfin — Media Playback"
# domain: 55
# folder: 55-playback
# status: active
# complexity: 3
# last_reviewed: 2026-09-02
# sprite: 50-core/icons.svg#jellyfin
# links:
#   adr: ADR-551
# provides: ["jellyfin"]
# requires: ["lib/registry", "lib/service-factory", "lib/hardening-profiles", "lib/memory-policy", "lib/creds"]
# ports: [5510]
# upstream_docs: ["https://jellyfin.org/docs/"]
# upstream_github: "https://github.com/jellyfin/jellyfin"
# nixpkgs_attr: "services.jellyfin"
# state_dir: "/var/lib/jellyfin"
# uds_socket: false
# systemd_hardened: true
# adr: ADR-551
# ---
# WAN stream + app login. 518 tiles this because accessGroup = stream.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix.jellyfin;
  svc = config.medinix;
  meta = config.medinix.manifest.jellyfin;

  # Kanonisch aus dem Manifest abgeleitet:
  inherit (meta) port stateDir uid;
  gid = (import ../lib/derive.nix).sharedGid;
  package = if cfg.package != null then cfg.package else pkgs.jellyfin;
  creds = import ../lib/creds.nix { inherit lib; };
  metadataDir = "${svc.storage.metadataDir}/jellyfin";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  memoryPolicy = import ../lib/memory-policy.nix { inherit lib config; };
  adminCred =
    if cfg.adminPasswordFile != null then
      cfg.adminPasswordFile
    else if cfg.adminPasswordCredential != null then
      cfg.adminPasswordCredential
    else
      null;

  jellyfinUrl =
    if svc.domain != null then "https://jellyfin.${svc.domain}" else "http://jellyfin.lan";
  jellyfinMetadataDir = "${metadataDir}/metadata";
  # Fail-closed: "auto" behauptet KEINE Hardware. Erst eine explizite Angabe
  # (intel/vaapi/amd/nvidia) claimt HW — und wird dann erzwungen (Assertion unten).
  accelExplicit = builtins.elem svc.hardware.accel [
    "intel"
    "vaapi"
    "amd"
    "nvidia"
  ];
  trickplayHwAccel = if accelExplicit then "true" else "false";

  systemXmlSeed = pkgs.writeText "jellyfin-system.xml" (
    builtins.replaceStrings
      [ "@METADATA_DIR@" "@LOCALE_LANG@" "@LOCALE_CC@" "@LOCALE_UI@" "@TRICKPLAY_HW_ACCEL@" ]
      [ jellyfinMetadataDir "de" "DE" "de-DE" trickplayHwAccel ]
      (builtins.readFile ./data/jellyfin-system.xml)
  );

  networkXmlSeed = pkgs.writeText "jellyfin-network.xml" (
    builtins.replaceStrings [ "@JELLYFIN_PORT@" "@JELLYFIN_URL@" ] [ (toString port) jellyfinUrl ] (
      builtins.readFile ./data/jellyfin-network.xml
    )
  );

  brandingXmlSeed = ./data/jellyfin-branding.xml;

  # Echter Transcode-Mechanismus: Jellyfin liest den Pfad aus config/encoding.xml
  # (TranscodingTempPath) — nicht aus einer Env-Variable.
  encodingXmlSeed = pkgs.writeText "jellyfin-encoding.xml" (
    builtins.replaceStrings
      [ "@TRANSCODE_DIR@" "@VAAPI_DEVICE@" ]
      [
        "/transcode"
        (if svc.hardware.renderDevice != null then svc.hardware.renderDevice else "")
      ]
      (builtins.readFile ./data/jellyfin-encoding.xml)
  );
in
{
  options.medinix.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin Media Server";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "null";
      description = ''
        Optionales Paket-Override für jellyfin.
        null = NixOS-Modul-Default aus nixpkgs.
      '';
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
      description = ''
        Pfad zur verschlüsselten Admin-Passwort-Datei (systemd-creds encrypt).
        ADR-5510: Jellyfin speichert First-Run-Status in DB (nicht Config) — Passwort
        MUSS vor dem ersten Start da sein (LoadCredentialEncrypted). Ohne: Web-UI blockiert.
      '';
    };

    adminPasswordCredential = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
      description = ''
        Pfad zur .cred-Datei (systemd-creds TPM-verschlüsselt) für Jellyfin Admin-Passwort.
        Wird via LoadCredentialEncrypted als mediNix-jellyfin-admin gemountet.
      '';
    };
  };

  config = lib.mkMerge [
    # ── 1. SERVICE-MANIFEST (Top-Level: Immer im Katalog, SSoT) ─────────────
    {
      medinix.manifest.jellyfin = {
        inherit (cfg) enable;
        num = 551;
        accessGroup = "stream";
        extraGroups = [
          "video"
          "render"
        ];

        ui = {
          title = "Jellyfin";
          description = "Medien-Streaming (Filme & Serien)";
          icon = "jellyfin";
          group = "Media";
        };

        monitoring = {
          inherit (cfg) enable;
          type = "http";
          healthPath = "/health";
          expectedStatus = 200;
        };

        ops = {
          priority = "high";
          ramBudget = "6G";
          notes = "Haupt-Mediaserver mit Hardware-Transcoding.";
        };

        sources = {
          upstream = "https://jellyfin.org/docs/";
          repo = "https://github.com/jellyfin/jellyfin";
          nixos = "https://wiki.nixos.org/wiki/Jellyfin";
          nixpkgsTest = "https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/jellyfin.nix";
          api = "https://api.jellyfin.org/";
        };
      };
    }

    # ── 2. RUNTIME & SYSTEMD (Nur aktiv wenn cfg.enable = true) ─────────────
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = adminCred != null;
          message = ''
            [mediNix] jellyfin is on the WAN stream vhost. Set
            medinix.jellyfin.adminPasswordCredential (or adminPasswordFile)
            to a systemd-creds blob. No default admin. No Pocket-ID SSO.
          '';
        }
        {
          assertion =
            let
              tfs = config.systemd.services.jellyfin.serviceConfig.TemporaryFileSystem or [ ];
            in
            lib.any (entry: lib.hasPrefix "/transcode" entry) (lib.toList tfs);
          message = "[mediNix/551-jellyfin] ARCHITEKTUR-VERLETZUNG: Transcoding MUSS zwingend im RAM (TemporaryFileSystem = '/transcode:size=...') stattfinden!";
        }
        {
          assertion = !accelExplicit || svc.hardware.renderDevice != null;
          message = ''
            [mediNix/551-jellyfin] medinix.hardware.accel = "${svc.hardware.accel}" ohne
            medinix.hardware.renderDevice. Dann gibt es kein DeviceAllow und kein
            Treiber-Scoping — der Dienst wuerde HW nur behaupten. Setze
            medinix.hardware.renderDevice (z. B. /dev/dri/renderD128) oder accel = "none".
          '';
        }
      ];

      # users.users.jellyfin besitzt die Engine (lib/decimal-framework.nix, UPG).
      # video/render stehen im Manifest (extraGroups).
      users.groups.media.gid = gid;

      systemd.tmpfiles.rules = [
        "d '${stateDir}' 0750 jellyfin media -"
        "d '${metadataDir}' 0775 jellyfin media -"
        "d '${jellyfinMetadataDir}' 0775 jellyfin media -"
      ];

      systemd.services.jellyfin = {
        unitConfig = {
          RequiresMountsFor = [
            stateDir
            svc.storage.mediaRoot
            metadataDir
          ];
        };
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        onFailure = [ "alert-ntfy@%n.service" ];
        preStart = ''
          # First-boot guard: Jellyfin must initialize its SQLite schema (ActivityLog etc.)
          # unseeded. Pre-seeding system.xml triggers migration against a non-existent DB (L7/docs/RUNBOOK.md §1).
          if [ ! -f '${stateDir}/data/jellyfin.db' ]; then
            exit 0
          fi

          ${pkgs.coreutils}/bin/mkdir -p '${stateDir}/config'
          if [ ! -f '${stateDir}/config/system.xml' ]; then
            ${pkgs.coreutils}/bin/cp '${systemXmlSeed}' '${stateDir}/config/system.xml'
            ${pkgs.coreutils}/bin/chmod 0640 '${stateDir}/config/system.xml'
          fi
          if [ ! -f '${stateDir}/config/network.xml' ]; then
            ${pkgs.coreutils}/bin/cp '${networkXmlSeed}' '${stateDir}/config/network.xml'
            ${pkgs.coreutils}/bin/chmod 0640 '${stateDir}/config/network.xml'
          fi
          if [ ! -f '${stateDir}/config/branding.xml' ]; then
            ${pkgs.coreutils}/bin/cp '${brandingXmlSeed}' '${stateDir}/config/branding.xml'
            ${pkgs.coreutils}/bin/chmod 0640 '${stateDir}/config/branding.xml'
          fi
          if [ ! -f '${stateDir}/config/encoding.xml' ]; then
            ${pkgs.coreutils}/bin/cp '${encodingXmlSeed}' '${stateDir}/config/encoding.xml'
            ${pkgs.coreutils}/bin/chmod 0640 '${stateDir}/config/encoding.xml'
          fi
        '';
        serviceConfig = lib.mkMerge [
          profiles.dotnet-gpu
          memoryPolicy.jellyfin
          {
            ExecStart = "${package}/bin/jellyfin --datadir ${stateDir} --cachedir /var/cache/jellyfin-cache --webdir ${package}/share/jellyfin-web";
            User = "jellyfin";
            Group = "media";
            UMask = "0002";
            SupplementaryGroups = [
              "video"
              "render"
            ];
            DeviceAllow = lib.mkIf (svc.hardware.renderDevice != null) [ "${svc.hardware.renderDevice} rwm" ];
            CacheDirectory = "jellyfin-cache";
            ReadWritePaths = [
              stateDir
              metadataDir
              "/var/cache/jellyfin-cache"
            ];
            BindReadOnlyPaths = [ "${svc.storage.mediaRoot}:${svc.storage.mediaRoot}" ];
            InaccessiblePaths = [ "-${creds.storeDir}" ];
            TemporaryFileSystem = "/transcode:size=4G,mode=0750,uid=${toString uid},gid=${toString gid}";
            LoadCredentialEncrypted = lib.mkIf (adminCred != null) [
              "jellyfin-admin-pw:${adminCred}"
            ];
          }
        ];
        environment = {
          JELLYFIN_PublishedServerUrl =
            if svc.domain != null then "https://jellyfin.${svc.domain}" else "http://jellyfin.lan";
        }
        // lib.optionalAttrs (accelExplicit && svc.hardware.accel != "nvidia") {
          LIBVA_DRIVER_NAME =
            {
              "intel" = "iHD";
              "vaapi" = "iHD";
              "amd" = "radeonsi";
            }
            .${svc.hardware.accel};
        }
        //
          lib.optionalAttrs
            (builtins.elem svc.hardware.accel [
              "intel"
              "vaapi"
              "amd"
            ])
            {
              VDPAU_DRIVER = "va_gl";
            };
      };

      hardware.graphics = lib.mkIf (svc.hardware.accel == "intel" || svc.hardware.accel == "vaapi") {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vpl-gpu-rt
          intel-vaapi-driver
          intel-compute-runtime
        ];
      };
    })
  ];
}
