# ---
# id: "570-storage"
# title: "Storage Tiering — MergerFS + Directory Structure (57-maintenance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 4
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5710
# ---
# Creates the logical directory structure (systemd.tmpfiles) and optionally
# MergerFS pools (if storage.backends is set).
#
# Two operational modes:
#   Simple (backends = {}): Flat structure under storage.mediaRoot. No MergerFS.
#   Tiered (backends != {}): MergerFS mounts per media type (hot + cold backends).
#
# ADR-5710: Host mounts physical disks (fileSystems."/mnt/ssd" etc.),
#           flake creates the logical structure + pools.
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  st  = cfg.storage;

  dataRoot    = toString st.mediaRoot;     # e.g. "/data"
  mediaTypes  = [ "movies" "series" "books" "music" ];
  hasHot      = st.backends ? hot;
  hasCold     = st.backends ? cold;
  hasBackends = hasHot && hasCold;
  hot         = st.backends.hot  or "";
  cold        = st.backends.cold or "";

  # Logical paths (Services always point here — regardless of mode)
  logicalDirs = map (t: "${dataRoot}/media/${t}") mediaTypes
    ++ [ "${dataRoot}/downloads" "${dataRoot}/cache" "${dataRoot}/incomplete" ];

  # tmpfiles: Base directory structure
  baseTmpfiles = map (d: "d '${d}' 0775 root media -") logicalDirs;

  # tmpfiles: Backend subdirectories (SSD + HDD sides for MergerFS)
  backendTmpfiles = lib.optionals hasBackends
    (  map (t: "d '${hot}/${t}' 0775 root media -") mediaTypes
    ++ map (t: "d '${cold}/${t}' 0775 root media -") mediaTypes );

  # MergerFS mount for a media type
  mergerfsMount = mediaType: {
    name  = "${dataRoot}/media/${mediaType}";
    value = {
      device  = "${hot}/${mediaType}:${cold}/${mediaType}";
      fsType  = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        # cache.files=partial: Mmap compatible (Jellyfin DB), still relatively fresh
        "cache.files=partial"
        "dropcacheonclose=true"
        # mfs = most-free-space: new files land on the backend with more space.
        # Prevents downloads always landing on the full HDD.
        "category.create=mfs"
        # Smaller chunk size → less fragmentation during tiering
        "minfreespace=10G"
      ];
      # Backend mounts must be ready before MergerFS mount
      depends = [ hot cold ];
      noCheck = true;
    };
  };
in
lib.mkIf (cfg.enable && st.enable) {

  # Ensure media group (GID 5000, SSOT from registry.nix)
  users.groups.media = lib.mkDefault { gid = 5000; };

  # Directory structure + permissions
  systemd.tmpfiles.rules = baseTmpfiles ++ backendTmpfiles;

  # MergerFS pools (only if hot + cold both defined)
  fileSystems = lib.mkIf hasBackends
    (lib.listToAttrs (map mergerfsMount mediaTypes));

  # mergerfs package must be in PATH for FUSE mounts
  environment.systemPackages = lib.mkIf hasBackends [ pkgs.mergerfs ];
}
