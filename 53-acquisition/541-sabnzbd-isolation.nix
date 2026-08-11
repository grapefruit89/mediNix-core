# ---
# id: "541-sabnzbd-isolation"
# title: "SABnzbd systemd-native Isolation (no docker)"
# domain: 50
# folder: 53-acquisition
# status: draft
# complexity: 3
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-10-vpn.md
#   modules:
#     - path: Nix Files/modules/50-media/default.nix
# provides: []
# requires: []
# ports: [5410]
# upstream_docs: []
# forum_links: []
# upstream_github: ''
# nixpkgs_attr: 'services.sabnzbd'
# state_dir: '/var/lib/sabnzbd'
# uds_socket: false
# systemd_hardened: true
# ---
# 53-acquisition/541-sabnzbd-isolation.nix — SABnzbd systemd isolation (no docker)
# Source: mediNix vector store (chat history), pattern-score 0.69
# VERIFY services.sabnzbd.* options via Context7 / nixos.org before deploy
{ lib, config, ... }:

let
  cfg = config.grapefruitMedia.sabnzbd;
  svc = (import ../lib/registry.nix { inherit lib; }).sabnzbd;
in
{
  options.grapefruitMedia.sabnzbd = {
    enable = lib.mkEnableOption "SABnzbd downloader (systemd-native, no docker)";
    downloadDir = lib.mkOption {
      type = lib.types.path;
      default = "/data/downloads";  # Tier B (SSD) per ABC-tiering
      description = "Active download workspace (SSD, not HDD).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sabnzbd = {
      enable = true;
      user = svc.name;
      group = "media";
      # ⚠️ VERIFY: services.sabnzbd.openPort / port option name in your nixpkgs.
      #   Context7: "nixos sabnzbd port option"
    };

    systemd.services.sabnzbd = {
      serviceConfig = {
        # Isolation: SABnzbd reaches only Caddy (127.0.0.1) + VPN if configured.
        RestrictNetworkInterfaces = [ "lo" "tun0" ];  # tun0 only if VPN module active
        # No docker, no privileged — systemd owns lifecycle.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
      };
    };

    networking.firewall.allowedTCPPorts = [ svc.port ];  # 5410 internal only
  };
}
