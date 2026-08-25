# ---
# id: "525-vpn-interface"
# title: "Flake-managed WireGuard Interface"
# domain: 52
# folder: 52-security
# status: active
# complexity: 4
# last_reviewed: 2026-08-18
# links: 
# provides: []
# requires: ["lib/registry"]
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# adr: ADR-5270
# ---

{ config, pkgs, lib, ... }:

let
  cfg       = config.medinix;
  vpn       = cfg.vpn;
  ifName    = vpn.interfaceName;
  credMount = "/run/credentials/wireguard-${ifName}.service/wg-private-key";
in
lib.mkIf (cfg.enable && vpn.enable && !vpn.useExistingInterface) {
  medinix.vpn.interface  = lib.mkDefault ifName;
  medinix.vpn.dnsServers = lib.mkDefault vpn.dns;
  services.vpnKillSwitch.vpnInterface = lib.mkDefault ifName;
  services.vpnKillSwitch.dnsServers = lib.mkDefault vpn.dns;

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

  systemd.services."wireguard-${ifName}" =
    lib.mkIf (vpn.privateKeyCredentialPath != null) {
      serviceConfig.LoadCredentialEncrypted = [
        "wg-private-key:${vpn.privateKeyCredentialPath}"
      ];
    };
}
