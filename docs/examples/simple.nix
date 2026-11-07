# ---
# id: "simple"
# title: "Minimale mediNix-Host-Konfiguration (Beispiel)"
# domain: 50
# folder: "docs/examples"
# status: example
# complexity: 1
# last_reviewed: 2026-11-07
# links:
#   adr: ADR-0000
# ---
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
  medinix = {
    enable = true;
    domain = "media.example.com"; # LAN unicast domain (NOT .local)

    # Storage — points to physical mount
    storage = {
      mediaRoot = "/mnt/ssd/media";
      metadataDir = "/mnt/ssd/cache";
      backends = {
        hot = "/mnt/ssd";
        cold = "/mnt/hdd";
      };
    };

    # Services — enable what you need
    jellyfin = {
      enable = true;
      # Kein Default-Admin: Jellyfin verlangt ein Passwort als
      # systemd-creds-Blob. systemd-creds encrypt --with-key=tpm2+host …
      adminPasswordCredential = "/var/lib/credstore.encrypted/jellyfin-admin.cred";
    };
    sonarr.enable = true;
    radarr.enable = true;
    prowlarr.enable = true;
    seerr.enable = true;

    # Ingress — Caddy, no TLS (LAN-only without ACME)
    ingress = {
      enable = true;
      # Kein implizites Vertrauen auf RFC1918: das LAN muss explizit stehen,
      # sonst bricht die Assertion den Build.
      trustedCidrs = [ "192.168.1.0/24" ];
      tls.mode = "off"; # HTTPS erst mit tls.acmeHost (WAN) oder "internal".
    };
  };
}
