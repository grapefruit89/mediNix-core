# ---
# id: "541-sabnzbd"
# title: "SABnzbd — Usenet Downloader (54-transfer, Dienst 541)"
# domain: 54
# folder: 54-transfer
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5410
#   skill: nixos-context7-gate
#   repo-harvest: sabnzbd/sabnzbd (no unix socket; -b 0 not -d for systemd; TimeoutStopSec loop #992)
# context7:
#   - query: "systemd.services serviceConfig NetworkNamespacePath BindReadOnlyPaths example"
#     library: /websites/nixos_manual_nixos_unstable
#     snippet: "BindPaths/ReadWritePaths/NetworkNamespacePath are valid serviceConfig keys"
# ---
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia.services.sabnzbd;
  svc = config.grapefruitMedia;
  port = 5410;  # 541 × 10
  uid  = 5410;
  gid  = 5000;
  stateDir = "/var/lib/sabnzbd-${toString port}";
in
{
  users.users.sabnzbd = {
    uid = uid; group = "media"; extraGroups = [ "media" ];
    home = stateDir; isSystemUser = true;
  };
  users.groups.media.gid = gid;

  systemd.services.sabnzbd = {
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = lib.mkMerge [
      {
        Type = "simple";
        ExecStart = "${pkgs.sabnzbd}/bin/sabnzbd -b 0 -f ${stateDir}/sabnzbd.ini --host 127.0.0.1 --port ${toString port}";
        User = "sabnzbd";
        Group = "media";
        UMask = "002";
        # Harvester #992: SABnzbd needs time to graceful-stop, else kill loop
        TimeoutStopSec = 30;
        # Harvester: no unix socket support — TCP on loopback only (never 0.0.0.0)
        PrivateDevices = true;  # no hardware needed
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        StateDirectory = "sabnzbd-${toString port}";
        ReadWritePaths = [ stateDir config.grapefruitMedia.storage.mediaRoot ];
      }
      # VPN confinement (ADR-5410): route only via WireGuard ns, no clearnet leak
      (lib.mkIf svc.usenet-confinement.enable {
        NetworkNamespacePath = "/run/netns/${svc.vpn.interface}";
        BindReadOnlyPaths = [ "/etc/usenet-resolv.conf:/etc/resolv.conf" ];
      })
    ];
    # API-Key via LoadCredentialEncrypted (ADR-5000: keine inline secrets)
    environment = lib.mkIf (cfg.apiKeyFile != null) {
      SABNZBD_API_KEY_FILE = cfg.apiKeyFile;
    };
  };
}
