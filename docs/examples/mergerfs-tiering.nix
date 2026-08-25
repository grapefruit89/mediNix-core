# docs/examples/mergerfs-tiering.nix — mediNix-core with MergerFS ABC-Tiering
#
# Use case: Host-side MergerFS union mount for stable library paths.
# Jellyfin sees one /srv/media tree; the Mover shifts large files to HDD
# on demand without breaking Jellyfin paths (no rescan needed).
#
# Tier A (NVMe): /var/lib — all service state (fast DB / metadata)
# Tier B (SSD) : /mnt/ssd — active downloads, staging
# Tier C (HDD) : /mnt/hdd — cold archive, spindown-eligible
# Union         : /srv/media = MergerFS(B + C) — Jellyfin library root
#
# Host provides: disk mounts + MergerFS union (NOT in mediNix-core module).
# mediNix Mover moves large files B→C when SSD free space < minFreeGb.
#
{ inputs, pkgs, ... }:
{
  imports = [
    inputs.mediNix-core.nixosModules.default
  ];

  # ── Physical disk mounts (host) ────────────────────────────────────────
  fileSystems."/mnt/ssd" = {
    device  = "/dev/disk/by-label/SSD";
    fsType  = "ext4";
  };
  fileSystems."/mnt/hdd" = {
    device  = "/dev/disk/by-label/HDD";
    fsType  = "ext4";
    options = [ "nofail" ];   # spin-down safe
  };

  # MergerFS union mount — stable logical path for Jellyfin.
  # Creates/moves go to SSD first (mfs = most-free-space policy).
  # DO NOT put this in mediNix-core: it's host-specific (FUSE, branch paths).
  fileSystems."/srv/media" = {
    device  = "/mnt/ssd/media:/mnt/hdd/media";
    fsType  = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=off"
      "dropcacheonclose=true"
      "category.create=mfs"    # create files on branch with most free space
      "minfreespace=20G"
    ];
    depends = [ "/mnt/ssd" "/mnt/hdd" ];
  };

  # ── mediNix-core ────────────────────────────────────────────────────────
  medinix = {
    enable = true;
    domain = "media.example.com";

    storage = {
      # Services write to the union mount — Jellyfin sees one tree
      mediaRoot   = "/srv/media";
      metadataDir = "/mnt/ssd/cache";   # SSD for fast DB access
      backends = {
        hot  = "/mnt/ssd";
        cold = "/mnt/hdd";
      };
    };

    jellyfin.enable   = true;
    sonarr.enable     = true;
    radarr.enable     = true;
    prowlarr.enable   = true;

    # Mover — ondemand B→C shift (no calendar timer, HDD can sleep)
    mover = {
      enable     = true;
      mode       = "ondemand";
      minFreeGb  = 50;
      stagingDir = "/mnt/ssd/media/downloads";
      archiveDir = "/mnt/hdd/media/library";
    };

    ingress.tls.mode = "off";   # or use acme + acmeCredential for WAN
  };
}
