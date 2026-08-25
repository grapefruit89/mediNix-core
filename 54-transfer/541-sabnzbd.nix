# ---
# id: "541-sabnzbd"
# title: "SABnzbd — Usenet Downloader (54-transfer, Service 541)"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links: 
# provides: []
# requires: ["lib/hardening-profiles", "lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5260, ADR-5050
# skill: nixos-context7-gate
# repo-harvest: sabnzbd/sabnzbd (native services.sabnzbd; Temp dir on tmpfs /run for SSD life; Env-Vars for config since sabnzbd.ini overwrites itself)
# context7: 
# - query: "services.sabnzbd enable settings example"
# library: /websites/nixos_manual_nixos_unstable
# snippet: "services.sabnzbd.enable + settings.misc"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.medinix.sabnzbd;
  svc = config.medinix;
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
      user = "sabnzbd";
      group = "media";
      openFirewall = false;
      configFile = null;
      allowConfigWrite = true;
      package = lib.mkIf (cfg.package != null) cfg.package;
      settings = {
        misc = {
          port = port;
          host = "127.0.0.1";
          language = svc.locale.language;
          download_dir = "${svc.storage.mediaRoot}/downloads";
          temp_dir = "/run/sabnzbd-tmp";
          check_new_rel = 0;
        };
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
          InaccessiblePaths = [ "/run/systemd/resolve" "/run/dbus/system_bus_socket" ];
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
      environment = { } // lib.optionalAttrs (cfg.serverCredentialFile != null) {
        # SABnzbd reads credential file via Env (Format: HOST/PORT/USER/PASS/SSL)
        SABNZBD__SERVER_0__CREDENTIAL_FILE = "/run/credentials/sabnzbd.service/mediNix-sabnzbd-server";
      };
    };

    # Moved inside mkIf cfg.enable
    

    # Strict tmpfs limit for SABnzbd to prevent OOM
    systemd.mounts = [{
      what = "tmpfs";
      where = "/run/sabnzbd-tmp";
      type = "tmpfs";
      options = "size=1G,mode=0700";
    }];


    medinix.persist.extraPaths = [ stateDir ];
    medinix.ingress.vhosts."sabnzbd" = { accessGroup = "internal"; };

    
    # Killswitch - Unconditionally enabled per Iron-Zero principles
    services.vpnKillSwitch.instances.sabnzbd = {
      enable = true;
      uid = uid;
    };
  };
}


