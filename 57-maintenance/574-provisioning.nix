# ---
# id: "574-provisioning"
# title: "Provisioning - register Download-Client + Indexer + Root Folders via API (oneshot, idempotent)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 4
# last_reviewed: 2026-08-19
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  flagFile = "/var/lib/mediNix-state/provisioned";  # in StateDirectory (writable, 0750)
  registry = (import ../lib/registry.nix { inherit lib; }).services;

  arrProv = pkgs.callPackage ../lib/arr-provision {};

in lib.mkIf cfg.maintenance.provisioning.enable {
  systemd.services.mediNix-provision = {
    description = "One-time provisioning: register SABnzbd + Prowlarr + Root Folders in *arr via API";
    after = [ "network.target" "sabnzbd.service" "prowlarr.service"
              "sonarr.service" "radarr.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig = {
      # Bootstrap: nur wenn Flag fehlt ODER force = true
      ConditionPathExists = lib.mkIf (!cfg.maintenance.provisioning.enforce)
        (if cfg.maintenance.provisioning.force then null else "!/var/lib/mediNix-state/provisioned");
    };
    serviceConfig = lib.mkMerge [
      # client-Profile: HTTP requests to 127.0.0.1 (API calls), no port binding
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
        ReadWritePaths = [
          "/var/lib/mediNix-state"
          (lib.mkIf cfg.sonarr.enable "-/var/lib/sonarr-${toString registry.sonarr.port}")
          (lib.mkIf cfg.radarr.enable "-/var/lib/radarr-${toString registry.radarr.port}")
        ];
        ExecStart = pkgs.writeShellScript "run-arr-provision" ''
          set -euo pipefail
          export SYNC_SONARR=${if cfg.sonarr.enable then "1" else "0"}
          export SYNC_RADARR=${if cfg.radarr.enable then "1" else "0"}
          export SYNC_PROWLARR=${if cfg.prowlarr.enable then "1" else "0"}
          export SYNC_SABNZBD=${if cfg.sabnzbd.enable then "1" else "0"}
          
          export SONARR_PORT="${toString registry.sonarr.port}"
          export RADARR_PORT="${toString registry.radarr.port}"
          export PROWLARR_PORT="${toString registry.prowlarr.port}"
          export SAB_PORT="${toString registry.sabnzbd.port}"
          
          export SONARR_KEY_FILE="/var/lib/sonarr-''${SONARR_PORT}/config.xml"
          export RADARR_KEY_FILE="/var/lib/radarr-''${RADARR_PORT}/config.xml"
          export PROWLARR_KEY_FILE="''${PROWLARR_API_FILE}"
          export SAB_KEY_FILE="''${SAB_API_FILE}"
          export SABNZBD_KEY_FILE="''${SAB_API_FILE}"
          
          export SONARR_ROOT_FOLDER="''${SONARR_ROOT:-}"
          export RADARR_ROOT_FOLDER="''${RADARR_ROOT:-}"
          
          # Build JSONs
          TARGETS="[]"
          APPS="[]"
          if [ "$SYNC_SONARR" = "1" ]; then
            TARGETS=$(echo "$TARGETS" | ${pkgs.jq}/bin/jq '. + [{"app":"sonarr", "port":'${SONARR_PORT}', "key_file":"'"$SONARR_KEY_FILE"'", "category":"tv"}]')
            APPS=$(echo "$APPS" | ${pkgs.jq}/bin/jq '. + [{"name":"Sonarr", "port":'${SONARR_PORT}', "key_file":"'"$SONARR_KEY_FILE"'", "sync_categories":[5000, 5030, 5040]}]')
          fi
          if [ "$SYNC_RADARR" = "1" ]; then
            TARGETS=$(echo "$TARGETS" | ${pkgs.jq}/bin/jq '. + [{"app":"radarr", "port":'${RADARR_PORT}', "key_file":"'"$RADARR_KEY_FILE"'", "category":"movies"}]')
            APPS=$(echo "$APPS" | ${pkgs.jq}/bin/jq '. + [{"name":"Radarr", "port":'${RADARR_PORT}', "key_file":"'"$RADARR_KEY_FILE"'", "sync_categories":[2000, 2010, 2020]}]')
          fi
          
          export TARGETS_JSON="$TARGETS"
          export APPS_JSON="$APPS"
          export INDEXERS_JSON="[]"
          export BACKUP_INDEXERS_JSON="[]"
          
          echo "Running arr-sync-keys..."
          ${arrProv}/bin/arr-sync-keys
          
          echo "Running arr-sync-settings..."
          ${arrProv}/bin/arr-sync-settings
          
          echo "Running arr-sync-download-clients..."
          ${arrProv}/bin/arr-sync-download-clients
          
          echo "Running arr-sync-prowlarr..."
          ${arrProv}/bin/arr-sync-prowlarr
          
          touch "$FLAG_FILE"
        '';
      }
    ];
    environment = {
      FLAG_FILE = flagFile;
      SAB_API_FILE = cfg.secrets.sabnzbdApiKeyFile;
      PROWLARR_API_FILE = cfg.secrets.prowlarrApiKeyFile;
    } // lib.optionalAttrs cfg.sonarr.enable {
      SONARR_ROOT = cfg.sonarr.rootFolder;
    } // lib.optionalAttrs cfg.radarr.enable {
      RADARR_ROOT = cfg.radarr.rootFolder;
    };
  };
}
