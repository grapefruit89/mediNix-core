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
    ./526-vpn-killswitch.nix
  ];

  services.vpnKillSwitch.instances.sabnzbd = {
    enable = cfg.sabnzbd.enable;

    # The service name and user are automatically derived from the name ("sabnzbd").
    vpnInterface    = cfg.vpn.interface;
    routingTable    = 51820;
    routingPriority = 100;

    blockedSocketPaths = [
      "/run/medinix"
      "/run/systemd/resolve"
      "/run/dbus/system_bus_socket"
    ];

    dnsServers = cfg.vpn.dnsServers;
  };

  # Prowlarr must also be sandboxed when usenet-confinement is active.
  # Without this, Prowlarr leaks the real IP while SABnzbd routes via VPN.
  services.vpnKillSwitch.instances.prowlarr = lib.mkIf cfg.prowlarr.enable {
    enable = true;

    vpnInterface    = cfg.vpn.interface;
    routingTable    = 51820;   # same routing table as sabnzbd (same VPN)
    routingPriority = 101;

    blockedSocketPaths = [
      "/run/medinix"
      "/run/systemd/resolve"
      "/run/dbus/system_bus_socket"
    ];

    dnsServers = cfg.vpn.dnsServers;
  };
}
