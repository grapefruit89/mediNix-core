# ---
# id: "570-storage"
# title: "Storage Tiering — Directory Structure + XFS/MergerFS Contract (57-maintenance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 2
# last_reviewed: 2026-11-26
# links:
#   adr: ADR-570
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
# Creates the logical directory structure (systemd.tmpfiles) and publishes
# recommended XFS/JBOD + MergerFS mount options (ADR-570).
#
# Two strictly validated operational modes (Poka-Yoke assertion):
#   Simple (backends = {}): Flat structure under storage.mediaRoot.
#   Tiered (backends = { hot; cold; }): Per-mediaType dirs on both tiers.
#
# 3-Tier Contract:
#   Tier 1 (NVMe State): OS, /var/lib, SQLite WAL, metadataDir (0 HDD wakes)
#   Tier 2 (SSD Scratch): SABnzbd downloadDir (PAR2/Unpack) + hot write-staging
#   Tier 3 (HDD JBOD): XFS (noatime, by-label, nofail), MKVs + static Audiobooks
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix;
  st = cfg.storage;
  tiers = lib.optionals (st.backends ? hot && st.backends ? cold) [
    st.backends.hot
    st.backends.cold
  ];
  mediaTypes = [
    "movies"
    "series"
    "books"
    "audiobooks"
    "music"
  ];
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion =
            (!cfg.enable || !st.enable)
            || st.backends == { }
            || (
              st.backends ? hot && st.backends ? cold && builtins.length (builtins.attrNames st.backends) == 2
            );
          message = "[mediNix/570-storage] storage.backends: entweder {} (Simple) oder exakt { hot; cold; } (Tiered, ADR-570).";
        }
      ];
    }

    (lib.mkIf (cfg.enable && st.enable) {
      # Ensure media group (sharedGid, SSoT: 50-core/derive.nix)
      users.groups.media = lib.mkDefault { gid = (import ../50-core/derive.nix).sharedGid; };

      medinix.recommended.mountOptions = {
        hdd = [
          "noatime"
          "nofail"
          "x-systemd.device-timeout=10s"
        ];
        mergerfs = [
          "defaults"
          "allow_other"
          "use_ino"
          "category.create=ff"
          "moveonenospc=mfs"
          "minfreespace=50G"
          "cache.readdir=true"
          "cache.entry=30"
          "cache.negative_entry=30"
          "cache.statfs=30"
          "cache.symlinks=true"
          "dropcacheonclose=true"
        ];
      };

      # SetGID (2775 root:media): neue Dateien und Unterordner erben Gruppe media (ADR-0000 §4).
      systemd.tmpfiles.rules = map (d: "d '${d}' 2775 root media -") (
        [
          (toString st.metadataDir)
          (toString st.downloadDir)
        ]
        ++ lib.concatMap (t: map (m: "${t}/${m}") mediaTypes) tiers
        ++ map (m: "${st.mediaRoot}/${m}") mediaTypes
      );
    })
  ];
}
