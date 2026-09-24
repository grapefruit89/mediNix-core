# ---
# id: "541-sabnzbd"
# title: "SABnzbd — Usenet Downloader (Optimized with RestrictNetworkInterfaces)"
# domain: 54
# folder: 54-transfer
# status: active
# last_reviewed: 2026-09-07
# requires: ["lib/hardening-profiles", "lib/registry"]
# adr: ADR-5260
# ---
# Writes: state + mediaRoot/downloads + tmpfs. Not the library tree.
# Secrets are LoadCredentialEncrypted, never files under mediaRoot.
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix.sabnzbd;
  svc = config.medinix;
  registry = (import ../lib/registry.nix { inherit lib; }).services;
  creds = import ../lib/creds.nix { inherit lib; };
  reg = registry.sabnzbd;
  inherit (reg) port;
  inherit (reg) uid;
  inherit (reg) stateDir;

  vpnIf =
    if (config.services.vpnKillSwitch.vpnInterface or "") != "" then
      config.services.vpnKillSwitch.vpnInterface
    else if svc.vpn.interface != null && svc.vpn.interface != "" then
      svc.vpn.interface
    else
      "wg0";
in
{
  config = lib.mkIf cfg.enable {
    users.users.sabnzbd = {
      inherit uid;
      group = "media";
      extraGroups = [ "media" ];
      home = stateDir;
      isSystemUser = true;
    };

    services.sabnzbd = {
      enable = true;
      user = "sabnzbd";
      group = "media";
      # H30: the registry stateDir is canonical. nixpkgs derives BOTH
      # StateDirectory and configFile (/var/lib/<stateDir>/sabnzbd.ini) from
      # this option — so mediNix must not additionally set
      # serviceConfig.StateDirectory (that was the conflict).
      stateDir = "sabnzbd-${toString port}";
      openFirewall = false;
      configFile = null;
      allowConfigWrite = true;
      package = lib.mkIf (cfg.package != null) cfg.package;
      settings.misc = {
        inherit port;
        host = "127.0.0.1";
        language = svc.locale.language;
        download_dir = "${svc.storage.mediaRoot}/downloads";
        temp_dir = "/run/sabnzbd-tmp";
        check_new_rel = 0;
      };
    };

    systemd.services.sabnzbd = {
      after = [
        "network.target"
        "run-sabnzbd\\x2dtmp.mount"
      ];
      requires = [ "run-sabnzbd\\x2dtmp.mount" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = lib.mkMerge [
        (import ../lib/hardening-profiles.nix { inherit lib; }).python
        {
          User = "sabnzbd";
          Group = "media";
          UMask = "0002";
          MemoryHigh = "2G";
          MemoryMax = "4G";
          InaccessiblePaths = [
            "-/run/systemd/resolve"
            "-/run/dbus/system_bus_socket"
            "-${creds.storeDir}"
          ];
          ReadWritePaths = [
            stateDir
            "${svc.storage.mediaRoot}/downloads"
            "/run/sabnzbd-tmp"
          ];
        }
        # Defense-in-Depth: cgroup-BPF-Socketfilter im Linux-Kernel
        (lib.mkIf (svc.usenet-confinement.enable && vpnIf != "") {
          RestrictNetworkInterfaces = [
            "lo"
            vpnIf
          ];
        })
        {
          LoadCredentialEncrypted = lib.mkMerge [
            (lib.mkIf (cfg.serverCredentialFile != null) [
              "mediNix-sabnzbd-server:${cfg.serverCredentialFile}"
            ])
            (lib.mkIf (svc.secrets.sabnzbdApiKeyFile != null) [
              "sabnzbd-api-key:${svc.secrets.sabnzbdApiKeyFile}"
            ])
          ];
        }
      ];
      environment = lib.optionalAttrs (cfg.serverCredentialFile != null) {
        SABNZBD__SERVER_0__CREDENTIAL_FILE = "/run/credentials/sabnzbd.service/mediNix-sabnzbd-server";
      };
    };

    systemd.mounts = [
      {
        what = "tmpfs";
        where = "/run/sabnzbd-tmp";
        type = "tmpfs";
        options = "size=1G,mode=0700";
      }
    ];

    medinix.persist.extraPaths = [ stateDir ];
    medinix.ingress.vhosts."sabnzbd" = {
      accessGroup = "internal";
    };

    services.vpnKillSwitch.instances.sabnzbd = {
      enable = svc.usenet-confinement.enable;
      inherit uid;
    };
  };
}
