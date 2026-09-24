# ---
# id: "500-host-integration"
# title: "500-host-integration module"
# domain: 50
# folder: 50-core
# status: active
# complexity: 3
# last_reviewed: 2026-08-25
# links: 
# provides: []
# requires: []
# ports: []
# upstream_docs: []
# forum_links: []
# upstream_github: ""
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: true
# ---
{ lib, config, ... }:

let
  cfg = config.medinix;
in {
  config = lib.mkIf cfg.enable {
    # Ownership (chameleon): "managed" = mediNix enables it on the host;
    # "external" = host already provides it, mediNix does NOT touch it;
    # "off" = no assumption.
    services.caddy.enable = lib.mkIf (cfg.hostIntegration.reverseProxy == "managed") true;
    # mkDefault: a host that explicitly disables the firewall under "managed"
    # gets the clean C1 assertion in 520 instead of an option conflict.
    networking.firewall.enable = lib.mkIf (cfg.hostIntegration.firewall == "managed") (lib.mkDefault true);
    networking.nftables.enable = lib.mkIf (cfg.hostIntegration.nftables == "managed") true;

    # We also apply the recommended nftables tables IF managed. If external, host must apply them.
    networking.nftables.tables = lib.mkIf (cfg.hostIntegration.nftables == "managed") cfg.recommended.nftables;

    # Kernel sysctl is NEVER managed, so we just export it in recommended.
  };
}
