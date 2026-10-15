# ---
# id: "570-storage"
# title: "Storage Tiering — MergerFS + Directory Structure (57-maintenance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 4
# last_reviewed: 2026-08-18
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
# adr: ADR-5710
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
{
  config,
  lib,
  ...
}:

let
  cfg = config.medinix;
  st = cfg.storage;
  mediaTypes = [
    "movies"
    "series"
    "books"
    "music"
  ];
  standardDirs = mediaTypes;
  backendsActive = (st.backends ? hot) && (st.backends ? cold);
  hot = st.backends.hot or "";
  cold = st.backends.cold or "";

  allDirs = [
    (toString st.metadataDir)
    (toString st.downloadDir)
  ]
  ++ map (dir: "${st.mediaRoot}/${dir}") standardDirs
  ++ lib.optionals backendsActive (
    map (t: "${hot}/${t}") mediaTypes ++ map (t: "${cold}/${t}") mediaTypes
  );
in
lib.mkIf (cfg.enable && st.enable) {
  # Ensure media group (GID 5000, SSOT from registry.nix)
  users.groups.media = lib.mkDefault { gid = 5000; };

  # Directory structure + permissions.
  # 2 vor 775 = SetGID: neue Dateien UND neue Unterordner erben die Gruppe media.
  # Notwendig seit der UPG-Umstellung (ADR-0000 §4): Primaergruppe der Dienste ist
  # jetzt ihr eigener Name, 0775 allein hinterlaesst Dateien als <dienst>:<dienst> —
  # Nachbardienste (Mitglied von media) koennten sie dann nicht mehr aendern.
  # Lokal verifiziert (systemd 259): eine spaetere d-Regel korrigiert Modus und
  # SetGID-Bit auch an bereits existierenden Verzeichnissen.
  systemd.tmpfiles.rules = map (d: "d '${d}' 2775 root media -") allDirs;
}
