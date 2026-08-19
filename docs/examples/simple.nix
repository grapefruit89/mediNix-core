# docs/examples/simple.nix — Minimal mediNix-core host config
#
# Use case: LAN-only media server, no VPN, no external access.
# What the host provides: disk mounts + storage paths.
# Everything else (services, Caddy, guardrails) comes from mediNix-core.
#
# After nixos-rebuild switch:
#   http://jellyfin.local → Jellyfin (mDNS)
#   http://jellyfin.<domain> → Jellyfin (Caddy, LAN-only)
#
{ inputs, ... }:
{
  imports = [
    inputs.mediNix-core.nixosModules.default
  ];

  # ── Physical disk mounts (host responsibility) ─────────────────────────
  fileSystems."/mnt/ssd" = {
    device = "/dev/disk/by-label/SSD";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-label/HDD";
    fsType = "ext4";
    options = [ "nofail" ];
  };

  # ── mediNix-core ────────────────────────────────────────────────────────
  grapefruitMedia = {
    enable = true;
    domain = "media.example.com";   # LAN unicast domain (NOT .local)

    # Storage — points to physical mount
    storage = {
      mediaRoot   = "/mnt/ssd/media";
      metadataDir = "/mnt/ssd/cache";
      backends = {
        hot  = "/mnt/ssd";
        cold = "/mnt/hdd";
      };
    };

    # Services — enable what you need
    jellyfin.enable    = true;
    sonarr.enable      = true;
    radarr.enable      = true;
    prowlarr.enable    = true;
    jellyseerr.enable  = true;

    # Ingress — Caddy, no TLS (LAN-only without ACME)
    ingress = {
      enable   = true;
      tls.mode = "off";   # TLS-003 assertion: not for jellyfin! use "acme" for WAN.
    };
  };
}
