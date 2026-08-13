{ config, pkgs, lib, ... }:

{
  imports = [
    ./vpn-killswitch.nix
  ];

  services.vpnKillSwitch.instances.sabnzbd = {
    enable = true;
    
    # Der Dienstname und User werden automatisch aus dem Namen ("sabnzbd") abgeleitet,
    # können aber überschrieben werden (z.B. unit = "sabnzbd.service"; user = "sabnzbd";).
    
    vpnInterface = "vpn0";

    routingTable = 51820;
    routingPriority = 100;

    blockedSocketPaths = [
      "/run/medinix"
      "/run/systemd/resolve"
      "/run/dbus/system_bus_socket"
    ];

    dnsServers = [
      "10.64.0.1"
    ];
  };
}
