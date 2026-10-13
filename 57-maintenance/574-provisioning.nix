# ---
# id: "574-provisioning"
# title: "Arr API provisioning oneshot"
# domain: 57
# last_reviewed: 2026-09-02
# ---
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.medinix;
  flagFile = "/var/lib/mediNix-state/provisioned";
  manifest = config.medinix.manifest or { };
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  arrProv = pkgs.callPackage ../lib/arr-provision { };
  cred = name: src: "${name}:${src}";
  credPath = name: "/run/credentials/mediNix-provision.service/${name}";

  # Dynamische Rollen-Ermittlung aus medinix.manifest (SSoT / ADR-0010)
  mediaManagers = lib.filterAttrs (
    _: m: m.enable && (m.arr.role or "none") == "media-manager"
  ) manifest;
  indexers = lib.filterAttrs (_: m: m.enable && (m.arr.role or "none") == "indexer") manifest;
  downloaders = lib.filterAttrs (_: m: m.enable && (m.arr.role or "none") == "downloader") manifest;

  hasIndexer = indexers != { };
  hasDownloader = downloaders != { };

  # Download-client targets for arr-sync-download-clients dynamically derived from manifest.
  # Category and apiVersion match each media-manager's manifest contract.
  downloadClientTargets = lib.mapAttrsToList (name: m: {
    inherit name;
    inherit (m) port;
    apiVersion = m.arr.apiVersion or "v3";
    apiKeyFile = credPath "${name}-apikey";
    category = m.arr.category;
  }) mediaManagers;

  # Applications dynamically registered with Prowlarr so Prowlarr pushes indexers down automatically.
  prowlarrApps = lib.mapAttrsToList (name: m: {
    inherit name;
    host = "127.0.0.1";
    inherit (m) port;
    apiKeyFile = credPath "${name}-apikey";
  }) mediaManagers;

  # Declarative Prowlarr indexers (only when an indexer is active).
  prowlarrIndexers = lib.optionals hasIndexer [
    {
      name = "treasure-maps.com";
      baseUrl = "https://treasure-maps.com";
      apiKeyFile = credPath "treasuremaps-apikey";
    }
  ];

  # Fresh-install bootstrap for SABnzbd's [categories] block — only applied
  # by locale_sync.py when sabnzbd.ini has no [categories] section yet, so
  # this never touches an already-configured live category scheme.
  sabnzbdCategoriesIni = ''
    [categories]
    [[movies]]
    name = movies
    order = 1
    pp = ""
    script = ""
    dir = movies
    newzbin = movies
    [[tv]]
    name = tv
    order = 2
    pp = ""
    script = ""
    dir = tv
    newzbin = tv
    [[music]]
    name = music
    order = 3
    pp = ""
    script = ""
    dir = music
    newzbin = music
    [[audiobooks]]
    name = audiobooks
    order = 4
    pp = ""
    script = ""
    dir = audiobooks
    newzbin = audiobooks
    [[readmeabook]]
    name = readmeabook
    order = 5
    pp = ""
    script = ""
    dir = audiobooks/audiobooks
    newzbin =
    [[schatztruhe]]
    name = schatztruhe
    order = 6
    pp = ""
    script = ""
    dir = schatztruhe
    newzbin = sceneCart
    [[prowlarr]]
    name = prowlarr
    order = 7
    pp = ""
    script = ""
    dir = prowlarr
    newzbin = prowlarr
    [[special]]
    name = special
    order = 8
    pp = ""
    script = ""
    dir = special
    newzbin = special
  '';
in
lib.mkIf cfg.maintenance.provisioning.enable {
  systemd.services.mediNix-provision = {
    description = "Register download clients / indexers / libraries via API";
    after = [
      "network.target"
    ]
    ++ lib.mapAttrsToList (name: _: "${name}.service") (
      lib.filterAttrs (_: m: m.enable && (m.arr.role or "none") != "none") manifest
    )
    ++ lib.optional (manifest.jellyfin.enable or false) "jellyfin.service"
    ++ lib.optional (manifest.seerr.enable or false) "seerr.service";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = lib.mkIf (!cfg.maintenance.provisioning.enforce) (
      if cfg.maintenance.provisioning.force then null else "!${flagFile}"
    );
    serviceConfig = lib.mkMerge [
      (import ../lib/hardening-profiles.nix { inherit lib; }).client
      {
        Type = "oneshot";
        TimeoutStartSec = "90s";
        Restart = "on-failure";
        RestartSec = "30s";
        User = "media";
        Group = "media";
        UMask = "002";
        StateDirectory = "mediNix-state";
        StateDirectoryMode = "0750";
        ReadWritePaths = [ "/var/lib/mediNix-state" ];
        LoadCredentialEncrypted = lib.flatten [
          (lib.optional (
            (manifest.jellyfin.enable or false) && (cfg.jellyfin.adminPasswordFile or null) != null
          ) (cred "jellyfin-admin-pw" cfg.jellyfin.adminPasswordFile))
          (lib.optional (
            (manifest.jellyfin.enable or false)
            && (cfg.jellyfin.adminPasswordFile or null) == null
            && (cfg.jellyfin.adminPasswordCredential or null) != null
          ) (cred "jellyfin-admin-pw" cfg.jellyfin.adminPasswordCredential))
          (lib.mapAttrsToList (
            name: _: cred "${name}-apikey" (cfg.secrets."${name}ApiKeyFile" or cfg.secrets.arrApiKeyFile)
          ) mediaManagers)
          (lib.optional hasIndexer (cred "prowlarr-apikey" cfg.secrets.prowlarrApiKeyFile))
          (lib.optional hasIndexer (cred "treasuremaps-apikey" cfg.secrets.treasureMapsApiKeyFile))
          (lib.optional hasDownloader (cred "sabnzbd-apikey" cfg.secrets.sabnzbdApiKeyFile))
          (lib.optional (manifest.seerr.enable or false) (cred "seerr-apikey" cfg.secrets.seerrApiKeyFile))
        ];
        ExecStart = pkgs.writeShellScript "run-arr-provision" ''
          set -euo pipefail
          ${arrProv}/bin/arr-sync-keys
          ${arrProv}/bin/arr-sync-settings
          ${arrProv}/bin/arr-sync-download-clients
          ${arrProv}/bin/arr-sync-prowlarr
          ${arrProv}/bin/arr-sync-locale
          ${arrProv}/bin/arr-sync-profiles
          if [ "$SYNC_JELLYFIN" = "1" ]; then
            ${arrProv}/bin/arr-sync-jellyfin
          fi
          if [ "$SYNC_SEERR" = "1" ]; then
            ${arrProv}/bin/arr-sync-seerr
          fi
          touch "$FLAG_FILE"
        '';
      }
    ];
    environment = {
      FLAG_FILE = flagFile;
      SYNC_SONARR = if (manifest.sonarr.enable or false) then "1" else "0";
      SYNC_RADARR = if (manifest.radarr.enable or false) then "1" else "0";
      SYNC_PROWLARR = if hasIndexer then "1" else "0";
      SYNC_SABNZBD = if hasDownloader then "1" else "0";
      SYNC_JELLYFIN = if (manifest.jellyfin.enable or false) then "1" else "0";
      SYNC_SEERR = if (manifest.seerr.enable or false) then "1" else "0";
      SONARR_PORT = toString (manifest.sonarr.port or registry.sonarr.port);
      RADARR_PORT = toString (manifest.radarr.port or registry.radarr.port);
      PROWLARR_PORT = toString (manifest.prowlarr.port or registry.prowlarr.port);
      SAB_PORT = toString (manifest.sabnzbd.port or registry.sabnzbd.port);
      SONARR_KEY_FILE = credPath "sonarr-apikey";
      RADARR_KEY_FILE = credPath "radarr-apikey";
      PROWLARR_KEY_FILE = credPath "prowlarr-apikey";
      SABNZBD_KEY_FILE = credPath "sabnzbd-apikey";
      SAB_KEY_FILE = credPath "sabnzbd-apikey";
      TARGETS_JSON = builtins.toJSON downloadClientTargets;
      TARGET_LANG = cfg.locale.language;
      TARGET_LOCALE = cfg.locale.default;
      CATEGORIES_INI = sabnzbdCategoriesIni;
      APPS_JSON = builtins.toJSON prowlarrApps;
      INDEXERS_JSON = builtins.toJSON prowlarrIndexers;
    }
    // lib.optionalAttrs (manifest.jellyfin.enable or false) {
      JELLYFIN_PORT = toString (manifest.jellyfin.port or registry.jellyfin.port);
      JELLYFIN_MOVIES_PATH = "${cfg.storage.mediaRoot}/movies";
      JELLYFIN_TV_PATH = "${cfg.storage.mediaRoot}/series";
      JELLYFIN_ADMIN_USER = "admin";
      JELLYFIN_ADMIN_PASSWORD_FILE = credPath "jellyfin-admin-pw";
    }
    // lib.optionalAttrs (manifest.seerr.enable or false) {
      SEERR_PORT = toString (manifest.seerr.port or registry.seerr.port);
      SEERR_CONFIG_JSON = builtins.toJSON {
        jellyfinHost = "127.0.0.1";
        jellyfinPort = manifest.jellyfin.port or registry.jellyfin.port;
        jellyfinUseSsl = false;
        adminUsername = "admin";
        adminPasswordFile = credPath "jellyfin-admin-pw";
        apiKeyFile = credPath "seerr-apikey";
        locale = "de";
        sonarr = {
          enabled = manifest.sonarr.enable or false;
          host = "127.0.0.1";
          port = manifest.sonarr.port or registry.sonarr.port;
          apiKeyFile = credPath "sonarr-apikey";
        };
        radarr = {
          enabled = manifest.radarr.enable or false;
          host = "127.0.0.1";
          port = manifest.radarr.port or registry.radarr.port;
          apiKeyFile = credPath "radarr-apikey";
        };
      };
    }
    // lib.optionalAttrs (manifest.sonarr.enable or false) {
      SONARR_ROOT = cfg.sonarr.rootFolder;
      SONARR_ROOT_FOLDER = cfg.sonarr.rootFolder;
    }
    // lib.optionalAttrs (manifest.radarr.enable or false) {
      RADARR_ROOT = cfg.radarr.rootFolder;
      RADARR_ROOT_FOLDER = cfg.radarr.rootFolder;
    };
  };
}
