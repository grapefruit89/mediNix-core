# ---
# id: "541-sabnzbd"
# title: "SABnzbd — Usenet Downloader (54-transfer, Service 541)"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5260, ADR-5050
#   skill: nixos-context7-gate
#   repo-harvest: sabnzbd/sabnzbd (native services.sabnzbd; Temp dir on tmpfs /run for SSD life; Env-Vars for config since sabnzbd.ini overwrites itself)
# context7:
#   - query: "services.sabnzbd enable settings example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "services.sabnzbd.enable + settings.misc"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.sabnzbd;
  svc = config.grapefruitMedia;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  reg = registry.sabnzbd;
  port = reg.port;
  uid = reg.uid;
  gid = reg.gid;
  stateDir = reg.stateDir;
in
{
  config = lib.mkIf cfg.enable {
    users.users.sabnzbd = {
      uid = uid; group = "media"; extraGroups = [ "media" ];
      home = stateDir; isSystemUser = true;
    };

    services.sabnzbd = {
      enable = true;
      openFirewall = false;
      configFile = null;
      allowConfigWrite = true;
      package = lib.mkIf (cfg.package != null) cfg.package;
      settings = {
        misc = {
          port = port;
          host = "127.0.0.1";
          language = svc.locale.language;
        };
      };
    };

    systemd.services.sabnzbd = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = lib.mkMerge [
        (import ../lib/hardening-profiles.nix { inherit lib; }).python
        {
          User = "sabnzbd";
          Group = "media";
          UMask = "0002";
          RuntimeDirectory = "sabnzbd-tmp";
          RuntimeDirectoryMode = "0700";
          StateDirectory = "sabnzbd-${toString port}";
          MemoryHigh = "2G";
          MemoryMax = "4G";
          InaccessiblePaths = [ "/run/systemd/resolve" "/run/dbus/system_bus_socket" ];
          ReadWritePaths = [
            stateDir
            "${svc.storage.mediaRoot}/downloads"
            "/run/sabnzbd-tmp"
          ];
        }
        # SABnzbd Usenet-Provider-Credentials (TPM-encrypted)
        (lib.mkIf (cfg.serverCredentialFile != null) {
          LoadCredentialEncrypted = [ "mediNix-sabnzbd-server:${cfg.serverCredentialFile}" ];
        })
      ];
      environment = {
        SABNZBD__MISC__TEMP_DIR = "/run/sabnzbd-tmp";
      } // lib.optionalAttrs (cfg.serverCredentialFile != null) {
        # SABnzbd reads credential file via Env (Format: HOST/PORT/USER/PASS/SSL)
        SABNZBD__SERVER_0__CREDENTIAL_FILE = "/run/credentials/sabnzbd.service/mediNix-sabnzbd-server";
      };
    };

    # Moved inside mkIf cfg.enable
    grapefruitMedia.persist.extraPaths = [ stateDir ];
    grapefruitMedia.ingress.vhosts."sabnzbd" = { accessGroup = "internal"; };

    # Credentials
    systemd.services.sabnzbd.serviceConfig.LoadCredentialEncrypted = lib.mkIf (cfg.secrets.sabnzbdApiKeyFile != null) [ "sabnzbd-api-key:${cfg.secrets.sabnzbdApiKeyFile}" ];

    # Killswitch
    services.vpnKillSwitch.instances.sabnzbd = lib.mkIf cfg.usenet-confinement.enable {
      enable = true;
      uid = uid;
    };
  };
}


