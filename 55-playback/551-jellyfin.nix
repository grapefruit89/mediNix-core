# ---
# id: "551-jellyfin"
# title: "Jellyfin Media Server (QSV, native systemd)"
# domain: 50
# folder: 55-playback
# status: active
# complexity: 4
# last_reviewed: 2026-08-10
# links:
#   adr: ADR-50-media
# provides: []
# requires: ["lib/registry", "lib/service-factory"]
# ports: [5510]
# upstream_docs: ["https://jellyfin.org/docs/"]
# forum_links: []
# upstream_github: "https://github.com/jellyfin/jellyfin"
# nixpkgs_attr: "services.jellyfin"
# state_dir: "/var/lib/jellyfin"
# uds_socket: false
# systemd_hardened: true
# ---
# 55-playback/551-jellyfin.nix — Jellyfin Media Server
{ lib, pkgs, config, ... }:

let
  cfg = config.grapefruitMedia;
  svc = (import ../lib/registry.nix { inherit lib; }).jellyfin;
in
{
  services.jellyfin = {
    enable = true;
    user = svc.name;
    group = "media";
  };

  systemd.services.jellyfin = {
    serviceConfig = {
      # Isolation: Loopback only (Jellyfin needs 127.0.0.1 for metadata APIs)
      RestrictNetworkInterfaces = [ "lo" ];
      # Hardware acceleration (optional, auto-detected)
      DeviceAllow = [ "/dev/dri/card0" "/dev/dri/renderD128" ];
    };
  };

  # Open ports for Jellyfin (via Caddy, not directly)
  networking.firewall.allowedTCPPorts = [ svc.port ];
}
