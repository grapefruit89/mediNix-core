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

  provScript = pkgs.writers.writePython3 "provision.py" {
    libraries = [ ];
    flakeIgnore = [ "E501" "E201" "E302" ];
  } (builtins.readFile ./provision.py);

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
        ExecStart = lib.getExe provScript;
      }
    ];
    environment = {
      FLAG_FILE = flagFile;
      SAB_API_FILE = cfg.secrets.sabnzbdApiKeyFile;
      PROWLARR_API_FILE = cfg.secrets.prowlarrApiKeyFile;
      SAB_PORT = toString registry.sabnzbd.port;
      PROWLARR_PORT = toString registry.prowlarr.port;
    } // lib.optionalAttrs cfg.sonarr.enable {
      SONARR_PORT = toString registry.sonarr.port;
      SONARR_ROOT = cfg.sonarr.rootFolder;
    } // lib.optionalAttrs cfg.radarr.enable {
      RADARR_PORT = toString registry.radarr.port;
      RADARR_ROOT = cfg.radarr.rootFolder;
    };
  };
}
