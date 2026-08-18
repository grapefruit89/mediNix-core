# ---
# id: "525-usenet-confinement"
# title: "SABnzbd VPN Killswitch Confinement"
# domain: 52
# folder: 52-security
# status: active
# complexity: 4
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5410, ADR-54
# ---
{ config, pkgs, lib, ... }:

let
  cfg = config.grapefruitMedia;
in
lib.mkIf (cfg.enable && cfg.usenet-confinement.enable) {
  imports = [
    ./vpn-killswitch.nix
  ];

  services.vpnKillSwitch.instances.sabnzbd = {
    enable = true;
    
    # Der Dienstname und User werden automatisch aus dem Namen ("sabnzbd") abgeleitet,
    # können aber überschrieben werden (z.B. unit = "sabnzbd.service"; user = "sabnzbd";).
    
    vpnInterface = cfg.vpn.interface;

    routingTable = 51820;
    routingPriority = 100;

    blockedSocketPaths = [
      "/run/medinix"
      "/run/systemd/resolve"
      "/run/dbus/system_bus_socket"
    ];

    dnsServers = cfg.vpn.dnsServers;
  };
}
