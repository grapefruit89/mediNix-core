# ---
# id: "574-provisioning"
# title: "Arr API provisioning oneshot"
# domain: 57
# last_reviewed: 2026-09-02
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix;
  flagFile = "/var/lib/mediNix-state/provisioned";
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  arrProv = pkgs.callPackage ../lib/arr-provision {};
  cred = name: src: "${name}:${src}";
  credPath = name: "/run/credentials/mediNix-provision.service/${name}";
in lib.mkIf cfg.maintenance.provisioning.enable {
  systemd.services.mediNix-provision = {
    description = "Register download clients / indexers / libraries via API";
    after = [ "network.target" "sabnzbd.service" "prowlarr.service"
              "sonarr.service" "radarr.service" ]
      ++ lib.optional cfg.jellyfin.enable "jellyfin.service"
      ++ lib.optional cfg.seerr.enable "seerr.service";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = lib.mkIf (!cfg.maintenance.provisioning.enforce)
      (if cfg.maintenance.provisioning.force then null else "!${flagFile}");
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
          (lib.optional (cfg.jellyfin.enable && (cfg.jellyfin.adminPasswordFile or null) != null)
            (cred "jellyfin-admin-pw" cfg.jellyfin.adminPasswordFile))
          (lib.optional (cfg.jellyfin.enable && (cfg.jellyfin.adminPasswordFile or null) == null && (cfg.jellyfin.adminPasswordCredential or null) != null)
            (cred "jellyfin-admin-pw" cfg.jellyfin.adminPasswordCredential))
          (lib.optional cfg.sonarr.enable (cred "sonarr-apikey" cfg.secrets.sonarrApiKeyFile))
          (lib.optional cfg.radarr.enable (cred "radarr-apikey" cfg.secrets.radarrApiKeyFile))
          (lib.optional cfg.prowlarr.enable (cred "prowlarr-apikey" cfg.secrets.prowlarrApiKeyFile))
          (lib.optional cfg.sabnzbd.enable (cred "sabnzbd-apikey" cfg.secrets.sabnzbdApiKeyFile))
          (lib.optional cfg.seerr.enable (cred "seerr-apikey" cfg.secrets.seerrApiKeyFile))
        ];
        ExecStart = pkgs.writeShellScript "run-arr-provision" ''
          set -euo pipefail
          ${arrProv}/bin/arr-sync-keys
          ${arrProv}/bin/arr-sync-settings
          ${arrProv}/bin/arr-sync-download-clients
          ${arrProv}/bin/arr-sync-prowlarr
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
      SYNC_SONARR = if cfg.sonarr.enable then "1" else "0";
      SYNC_RADARR = if cfg.radarr.enable then "1" else "0";
      SYNC_PROWLARR = if cfg.prowlarr.enable then "1" else "0";
      SYNC_SABNZBD = if cfg.sabnzbd.enable then "1" else "0";
      SYNC_JELLYFIN = if cfg.jellyfin.enable then "1" else "0";
      SYNC_SEERR = if cfg.seerr.enable then "1" else "0";
      SONARR_PORT = toString registry.sonarr.port;
      RADARR_PORT = toString registry.radarr.port;
      PROWLARR_PORT = toString registry.prowlarr.port;
      SAB_PORT = toString registry.sabnzbd.port;
      SONARR_KEY_FILE = credPath "sonarr-apikey";
      RADARR_KEY_FILE = credPath "radarr-apikey";
      PROWLARR_KEY_FILE = credPath "prowlarr-apikey";
      SABNZBD_KEY_FILE = credPath "sabnzbd-apikey";
      SAB_KEY_FILE = credPath "sabnzbd-apikey";
    } // lib.optionalAttrs cfg.jellyfin.enable {
      JELLYFIN_PORT = toString registry.jellyfin.port;
      JELLYFIN_MOVIES_PATH = "${cfg.storage.mediaRoot}/movies";
      JELLYFIN_TV_PATH = "${cfg.storage.mediaRoot}/tvshows";
      JELLYFIN_ADMIN_USER = "admin";
      JELLYFIN_ADMIN_PASSWORD_FILE = credPath "jellyfin-admin-pw";
    } // lib.optionalAttrs cfg.seerr.enable {
      SEERR_PORT = toString registry.seerr.port;
      SEERR_CONFIG_JSON = builtins.toJSON {
        jellyfinHost = "127.0.0.1";
        jellyfinPort = registry.jellyfin.port;
        jellyfinUseSsl = false;
        adminUsername = "admin";
        adminPasswordFile = credPath "jellyfin-admin-pw";
        apiKeyFile = credPath "seerr-apikey";
        locale = "de";
        sonarr = {
          enabled = cfg.sonarr.enable;
          host = "127.0.0.1";
          port = registry.sonarr.port;
          apiKeyFile = credPath "sonarr-apikey";
        };
        radarr = {
          enabled = cfg.radarr.enable;
          host = "127.0.0.1";
          port = registry.radarr.port;
          apiKeyFile = credPath "radarr-apikey";
        };
      };
    } // lib.optionalAttrs cfg.sonarr.enable {
      SONARR_ROOT = cfg.sonarr.rootFolder;
    } // lib.optionalAttrs cfg.radarr.enable {
      RADARR_ROOT = cfg.radarr.rootFolder;
    };
  };
}
