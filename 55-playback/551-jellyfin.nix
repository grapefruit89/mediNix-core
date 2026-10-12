# ---
# id: "551-jellyfin"
# title: "Jellyfin — Media Playback"
# domain: 55
# last_reviewed: 2026-09-02
# sprite: 50-core/icons.svg#jellyfin
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
  reg = (import ../lib/registry.nix { inherit lib; }).services.jellyfin;
  meta = config.medinix.manifest.jellyfin;

  # Kanonisch aus dem Manifest abgeleitet:
  inherit (meta) port uid stateDir;
  gid = 5000;
  creds = import ../lib/creds.nix { inherit lib; };
  metadataDir = "${svc.storage.metadataDir}/jellyfin";
  profiles = import ../lib/hardening-profiles.nix { inherit lib; };
  memoryPolicy = import ../lib/memory-policy.nix { inherit lib; };
  adminCred =
    if cfg.adminPasswordFile != null then
      cfg.adminPasswordFile
    else if cfg.adminPasswordCredential != null then
      cfg.adminPasswordCredential
    else
      null;

  jellyfinUrl =
    if svc.domain != null then "https://jellyfin.${svc.domain}" else "http://jellyfin.local";
  jellyfinMetadataDir = "${metadataDir}/metadata";
  trickplayHwAccel = if svc.hardware.accel != "none" then "true" else "false";

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
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Pfad zur verschlüsselten Admin-Passwort-Datei (systemd-creds encrypt).
        ADR-5510: Jellyfin speichert First-Run-Status in DB (nicht Config) — Passwort
        MUSS vor dem ersten Start da sein (LoadCredentialEncrypted). Ohne: Web-UI blockiert.
      '';
    };

    adminPasswordCredential = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
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
        enable = cfg.enable;
        num = reg.num;
        accessGroup = "stream";

        ui = {
          title = "Jellyfin";
          description = "Medien-Streaming (Filme & Serien)";
          icon = "jellyfin";
          group = "Media";
        };

        monitoring = {
          enable = cfg.enable;
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
          assertion = meta.num == reg.num;
          message = "[mediNix/551-jellyfin] Manifest-Nummer (${toString meta.num}) stimmt nicht mit lib/registry.nix (${toString reg.num}) überein!";
        }
      ];

  users.users.jellyfin = {
    inherit uid;
    group = "media";
    extraGroups = [
      "video"
      "render"
    ];
    home = stateDir;
    isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.tmpfiles.rules = [
    "d '${metadataDir}' 0775 jellyfin media -"
    "d '${jellyfinMetadataDir}' 0775 jellyfin media -"
  ];

  systemd.services.jellyfin = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    onFailure = [ "alert-ntfy@%n.service" ];
    preStart = ''
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
    '';
    serviceConfig = lib.mkMerge [
      profiles.dotnet-gpu
      memoryPolicy.jellyfin
      {
        ExecStart = "${pkgs.jellyfin}/bin/jellyfin --datadir ${stateDir} --cachedir /var/cache/jellyfin-cache --webdir ${pkgs.jellyfin-web}/share/jellyfin-web";
        User = "jellyfin";
        Group = "media";
        UMask = "0002";
        SupplementaryGroups = [
          "video"
          "render"
        ];
        DeviceAllow = lib.mkIf (svc.hardware.renderDevice != null) [ "${svc.hardware.renderDevice} rwm" ];
        StateDirectory = "jellyfin-${toString port}";
        CacheDirectory = "jellyfin-cache";
        ReadWritePaths = [
          stateDir
          metadataDir
          "/var/cache/jellyfin-cache"
        ];
        BindReadOnlyPaths = [ "${svc.storage.mediaRoot}:${svc.storage.mediaRoot}" ];
        InaccessiblePaths = [ "-${creds.storeDir}" ];
        TemporaryFileSystem = "/transcode:size=4G";
        RuntimeDirectory = "jellyfin-transcode";
        LoadCredentialEncrypted = lib.mkIf (adminCred != null) [
          "jellyfin-admin-pw:${adminCred}"
        ];
      }
    ];
    environment = {
      JELLYFIN_PublishedServerUrl =
        if svc.domain != null then "https://jellyfin.${svc.domain}" else "http://jellyfin.local";
      JELLYFIN_TRANSCODE_DIR = "/transcode";
    }
    // lib.optionalAttrs (svc.hardware.accel != "none") {
      LIBVA_DRIVER_NAME =
        {
          "auto" = "iHD";
          "intel" = "iHD";
          "vaapi" = "iHD";
          "amd" = "radeonsi";
          "nvidia" = null;
        }
        .${svc.hardware.accel} or null;
      VDPAU_DRIVER = "va_gl";
    }
    // lib.optionalAttrs (adminCred != null) {
      JELLYFIN_ADMIN_PASSWORD__FILE = "/run/credentials/jellyfin.service/jellyfin-admin-pw";
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
