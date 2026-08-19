# ---
# id: "525-vpn-interface"
# title: "Flake-managed WireGuard Interface & Usenet Confinement"
# domain: 52
# folder: 52-security
# status: active
# complexity: 4
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5410, ADR-5270
# ---
# Creates the WireGuard interface if vpn.enable = true && vpn.useExistingInterface = false.
# Automatically sets grapefruitMedia.vpn.interface + vpn.dnsServers (for Killswitch compat).
# Configures SABnzbd VPN killswitch confinement when usenet-confinement.enable = true.
# The Private Key is supplied exclusively via systemd-credentials (LoadCredentialEncrypted).
# Flake-first: Host only provides the physical credential path.
{ config, pkgs, lib, ... }:

let
  cfg       = config.grapefruitMedia;
  vpn       = cfg.vpn;
  ifName    = vpn.interfaceName;
  # Credential path at runtime (after LoadCredentialEncrypted)
  credMount = "/run/credentials/wireguard-${ifName}.service/wg-private-key";
in
lib.mkMerge [
  # WireGuard Interface (flake-first)
  (lib.mkIf (cfg.enable && vpn.enable && !vpn.useExistingInterface) {
    # Automatically set vpn.interface + dnsServers (Killswitch + Guardrail-Compat)
    # lib.mkDefault: Host can override if necessary
    grapefruitMedia.vpn.interface  = lib.mkDefault ifName;
    grapefruitMedia.vpn.dnsServers = lib.mkDefault vpn.dns;

    # WireGuard Interface (NixOS-native, no wg-quick, no Docker)
    networking.wireguard.interfaces.${ifName} = {
      ips            = vpn.address;
      privateKeyFile = credMount;

      peers = lib.optional (vpn.peer.publicKey != "") {
        publicKey           = vpn.peer.publicKey;
        endpoint            = vpn.peer.endpoint;
        allowedIPs          = vpn.peer.allowedIPs;
        persistentKeepalive = vpn.peer.persistentKeepalive;
      };
    };

    # Private Key via systemd-credentials (LoadCredentialEncrypted)
    # Must be declared in the wireguard unit itself, so that the credential
    # is available under credMount before the interface starts.
    systemd.services."wireguard-${ifName}" =
      lib.mkIf (vpn.privateKeyCredentialPath != null) {
        serviceConfig.LoadCredentialEncrypted = [
          "wg-private-key:${vpn.privateKeyCredentialPath}"
        ];
      };
  })

  # SABnzbd VPN Killswitch Confinement Instance
  (lib.mkIf (cfg.enable && cfg.usenet-confinement.enable) {
    services.vpnKillSwitch.instances.sabnzbd = {
      enable = true;

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
  })

  # Prowlarr must also be sandboxed when usenet-confinement is active.
  (lib.mkIf (cfg.enable && cfg.usenet-confinement.enable && cfg.prowlarr.enable) {
    services.vpnKillSwitch.instances.prowlarr = {
      enable = true;

      vpnInterface    = cfg.vpn.interface;
      routingTable    = 51820;
      routingPriority = 101;

      blockedSocketPaths = [
        "/run/medinix"
        "/run/systemd/resolve"
        "/run/dbus/system_bus_socket"
      ];

      dnsServers = cfg.vpn.dnsServers;
    };
  })

]
