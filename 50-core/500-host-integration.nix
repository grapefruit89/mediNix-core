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
    # If a resource is set to "managed", we explicitly enable it on the host.
    services.caddy.enable = lib.mkIf (cfg.hostIntegration.reverseProxy == "managed") true;
    networking.nftables.enable = lib.mkIf (cfg.hostIntegration.nftables == "managed") true;
    
    # We also apply the recommended nftables tables IF managed. If external, host must apply them.
    networking.nftables.tables = lib.mkIf (cfg.hostIntegration.nftables == "managed") cfg.recommended.nftables;
    
    # Kernel sysctl and firewall options are NEVER managed, so we just export them in recommended.
  };
}
