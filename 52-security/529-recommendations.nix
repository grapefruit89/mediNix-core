# ---
# id: "529-recommendations"
# title: "529-recommendations module"
# domain: 52
# folder: 52-security
# status: active
# complexity: 3
# last_reviewed: 2026-08-25
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
# ---

{ lib, config, ... }:

let
  cfg = config.medinix;
in {
  config = lib.mkIf cfg.enable {
    # Provide the baseline sysctl hardening recommendations
    medinix.recommended.sysctl = {
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "kernel.kexec_load_disabled" = 1;
      "kernel.yama.ptrace_scope" = 1;
      "fs.protected_hardlinks" = 1;
      "fs.protected_symlinks" = 1;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      
      # For VPN Killswitch policy routing, rp_filter must be 2 (loose)
      "net.ipv4.conf.all.rp_filter" = 2;
      "net.ipv4.conf.default.rp_filter" = 2;
    };

    # Provide the firewall recommendations (especially checkReversePath for VPN)
    medinix.recommended.firewall.checkReversePath = false; # Required for Wireguard Policy Routing
    
    # Mount Options
    medinix.recommended.mountOptions.staging = [ "noexec" "nosuid" "nodev" ];
  };
}
