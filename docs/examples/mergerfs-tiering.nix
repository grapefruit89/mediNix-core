# ---
# id: "mergerfs-tiering"
# title: "mergerfs-ABC-Tiering (Beispiel)"
# domain: 57
# folder: "docs/examples"
# status: example
# complexity: 2
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-570
# ---
# Bewusst NICHT in checks.mediNix-example-*: rein host-seitig (MergerFS-
# Mounts), enthaelt kein mediNix-Modul und ist deshalb nicht evaluierbar.
# docs/examples/mergerfs-tiering.nix — mediNix-core with 3-Tier XFS JBOD + MergerFS
#
# Tier 1 (NVMe State): /var/lib + /mnt/ssd/cache — DBs, SQLite WAL, Jellyfin Metadata (0 HDD wakes)
# Tier 2 (SSD Scratch): /mnt/ssd — SABnzbd downloads/PAR2 + hot write-staging
# Tier 3 (HDD JBOD):    /mnt/hdd — XFS (noatime, by-label, nofail), MKVs + static Audiobooks
# Union:                /srv/media = MergerFS(SSD + HDD, category.create=ff, cache.readdir=true)
#
# Host provides: disk mounts + MergerFS union (NOT in mediNix-core module).
# mediNix Mover batches whole release folders B→C during idle piggyback windows.
#
{ inputs, ... }:
{
  imports = [
    inputs.mediNix-core.nixosModules.default
  ];

  # ── Physical disk mounts (host) ────────────────────────────────────────
  fileSystems."/mnt/ssd" = {
    device = "/dev/disk/by-label/SSD";
    fsType = "xfs";
    options = [ "noatime" ];
  };
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-label/media-01";
    fsType = "xfs";
    options = [
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # MergerFS union mount — stable logical path for Jellyfin.
  # category.create=ff writes new imports to SSD first; cache.readdir=true
  # serves directory listings from kernel cache without waking the HDD.
  # DO NOT put this in mediNix-core: it's host-specific (FUSE, branch paths).
  fileSystems."/srv/media" = {
    device = "/mnt/ssd:/mnt/hdd";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "category.create=ff" # Immer zuerst auf Tier-2 SSD schreiben
      "moveonenospc=mfs" # Bei voller Platte auf andere Branch ausweichen
      "minfreespace=50G" # XFS B-Tree-Fragmentierung vermeiden
      "cache.readdir=true" # Moderner Kernel-Ersatz fuer cache_dirs
      "cache.entry=30"
      "cache.negative_entry=30"
      "cache.statfs=30"
      "cache.symlinks=true"
      "dropcacheonclose=true"
    ];
    depends = [
      "/mnt/ssd"
      "/mnt/hdd"
    ];
  };

  # ── mediNix-core ────────────────────────────────────────────────────────
  medinix = {
    enable = true;
    domain = "media.example.com";

    storage = {
      # Services write to the union mount — Jellyfin sees one tree
      mediaRoot = "/srv/media";
      downloadDir = "/mnt/ssd/downloads"; # Tier-2 SSD Scratch (PAR2/Unpack)
      metadataDir = "/mnt/ssd/cache"; # Tier-1/SSD Metadata (never on HDD)
      backends = {
        hot = "/mnt/ssd";
        cold = "/mnt/hdd";
      };
    };

    jellyfin.enable = true;
    sonarr.enable = true;
    radarr.enable = true;
    prowlarr.enable = true;

    # Mover — piggyback B→C write-batching (whole release folders, ionice -c 3)
    mover = {
      enable = true;
      mode = "ondemand";
      minFreeGb = 50;
      criticalFreeGb = 10;
      archiveDevice = "/dev/disk/by-label/media-01";
      stagingDir = "/mnt/ssd/movies";
      archiveDir = "/mnt/hdd/movies";
    };

    ingress.tls.mode = "off"; # or use acme + acmeCredential for WAN
  };
}
