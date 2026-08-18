# ---
# id: "570-storage"
# title: "Storage Tiering — MergerFS + Verzeichnisstruktur (57-maintenance)"
# domain: 57
# folder: 57-maintenance
# status: active
# complexity: 4
# last_reviewed: 2026-08-18
# links:
#   adr: ADR-5710
# ---
# Erstellt die logische Verzeichnisstruktur (systemd.tmpfiles) und optional
# MergerFS-Pools (wenn storage.backends gesetzt).
#
# Zwei Betriebsmodi:
#   Einfach  (backends = {}):  Flat-Struktur unter storage.mediaRoot. Kein MergerFS.
#   Tiered   (backends != {}): MergerFS-Mounts pro Medientyp (hot + cold Backends).
#
# ADR-5710: Host mountet physische Platten (fileSystems."/mnt/ssd" etc.),
#           Flake erstellt die logische Struktur + Pools.
{ config, lib, pkgs, ... }:

let
  cfg = config.grapefruitMedia;
  st  = cfg.storage;

  dataRoot    = toString st.mediaRoot;     # z.B. "/data"
  mediaTypes  = [ "movies" "series" "books" "music" ];
  hasHot      = st.backends ? hot;
  hasCold     = st.backends ? cold;
  hasBackends = hasHot && hasCold;
  hot         = st.backends.hot  or "";
  cold        = st.backends.cold or "";

  # Logische Pfade (Services zeigen immer hierauf — unabhängig vom Modus)
  logicalDirs = map (t: "${dataRoot}/media/${t}") mediaTypes
    ++ [ "${dataRoot}/downloads" "${dataRoot}/cache" "${dataRoot}/incomplete" ];

  # tmpfiles: Basis-Verzeichnisstruktur
  baseTmpfiles = map (d: "d '${d}' 0775 root media -") logicalDirs;

  # tmpfiles: Backend-Unterverzeichnisse (SSD + HDD Seiten für MergerFS)
  backendTmpfiles = lib.optionals hasBackends
    (  map (t: "d '${hot}/${t}' 0775 root media -") mediaTypes
    ++ map (t: "d '${cold}/${t}' 0775 root media -") mediaTypes );

  # MergerFS-Mount für einen Medientyp
  mergerfsMount = mediaType: {
    name  = "${dataRoot}/media/${mediaType}";
    value = {
      device  = "${hot}/${mediaType}:${cold}/${mediaType}";
      fsType  = "fuse.mergerfs";
      options = [
        "defaults"
        "allow_other"
        "use_ino"
        # cache.files=partial: Mmap-kompatibel (Jellyfin DB), trotzdem relativ frisch
        "cache.files=partial"
        "dropcacheonclose=true"
        # mfs = most-free-space: neue Dateien landen auf dem Backend mit mehr Platz.
        # Verhindert dass Downloads immer auf der vollen HDD landen.
        "category.create=mfs"
        # Kleinere Chunk-Größe → weniger Fragmentierung beim Tiering
        "minfreespace=10G"
      ];
      # Backend-Mounts müssen vor dem MergerFS-Mount fertig sein
      depends = [ hot cold ];
      noCheck = true;
    };
  };
in
lib.mkIf (cfg.enable && st.enable) {

  # media-Gruppe sicherstellen (GID 5000, SSoT aus registry.nix)
  users.groups.media = lib.mkDefault { gid = 5000; };

  # Verzeichnisstruktur + Rechte
  systemd.tmpfiles.rules = baseTmpfiles ++ backendTmpfiles;

  # MergerFS-Pools (nur wenn hot + cold beide definiert)
  fileSystems = lib.mkIf hasBackends
    (lib.listToAttrs (map mergerfsMount mediaTypes));

  # mergerfs Package muss im PATH für FUSE-Mounts
  environment.systemPackages = lib.mkIf hasBackends [ pkgs.mergerfs ];
}
