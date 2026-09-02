# ---
# id: "541-sabnzbd"
# title: "SABnzbd — Usenet Downloader"
# domain: 54
# folder: 54-transfer
# status: active
# last_reviewed: 2026-09-02
# requires: ["lib/hardening-profiles", "lib/registry"]
# adr: ADR-5260
# ---
# Writes: state + mediaRoot/downloads + tmpfs. Not the library tree.
# Secrets are LoadCredentialEncrypted, never files under mediaRoot.
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.sabnzbd;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  creds = import ../lib/creds.nix { inherit lib; };
  reg = registry.sabnzbd;
  port = reg.port;
  uid = reg.uid;
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
      user = "sabnzbd";
      group = "media";
      openFirewall = false;
      configFile = null;
      allowConfigWrite = true;
      package = lib.mkIf (cfg.package != null) cfg.package;
      settings.misc = {
        port = port;
        host = "127.0.0.1";
        language = svc.locale.language;
        download_dir = "${svc.storage.mediaRoot}/downloads";
        temp_dir = "/run/sabnzbd-tmp";
        check_new_rel = 0;
      };
    };

    systemd.services.sabnzbd = {
      after = [ "network.target" "run-sabnzbd\\x2dtmp.mount" ];
      requires = [ "run-sabnzbd\\x2dtmp.mount" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = lib.mkMerge [
        (import ../lib/hardening-profiles.nix { inherit lib; }).python
        {
          User = "sabnzbd";
          Group = "media";
          UMask = "0002";
          StateDirectory = "sabnzbd-${toString port}";
          MemoryHigh = "2G";
          MemoryMax = "4G";
          InaccessiblePaths = [ "/run/systemd/resolve" "/run/dbus/system_bus_socket" creds.storeDir ];
          ReadWritePaths = [
            stateDir
            "${svc.storage.mediaRoot}/downloads"
            "/run/sabnzbd-tmp"
          ];
        }
        {
          LoadCredentialEncrypted = lib.mkMerge [
            (lib.mkIf (cfg.serverCredentialFile != null) [ "mediNix-sabnzbd-server:${cfg.serverCredentialFile}" ])
            (lib.mkIf (svc.secrets.sabnzbdApiKeyFile != null) [ "sabnzbd-api-key:${svc.secrets.sabnzbdApiKeyFile}" ])
          ];
        }
      ];
      environment = lib.optionalAttrs (cfg.serverCredentialFile != null) {
        SABNZBD__SERVER_0__CREDENTIAL_FILE = "/run/credentials/sabnzbd.service/mediNix-sabnzbd-server";
      };
    };

    systemd.mounts = [{
      what = "tmpfs";
      where = "/run/sabnzbd-tmp";
      type = "tmpfs";
      options = "size=1G,mode=0700";
    }];

    medinix.persist.extraPaths = [ stateDir ];
    medinix.ingress.vhosts."sabnzbd" = { accessGroup = "internal"; };

    services.vpnKillSwitch.instances.sabnzbd = {
      enable = svc.usenet-confinement.enable;
      uid = uid;
    };
  };
}
