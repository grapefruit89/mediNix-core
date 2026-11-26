---
title: Storage & Mover
type: Concept
last_reviewed: 2026-10-17
---
# Storage & Mover

**Concept — Architektur-Absicht / Composition Boundary, keine bewiesene
Runtime-Eigenschaft auf jedem Host.**

mediNix-core beansprucht **nicht**, die physischen Laufwerke zu besitzen. Es
braucht einen **Storage-Contract**; das Mounten der Platten gehört dem Host /
Gesamtsystem (ADR-570). Den **Mover** bringt mediNix-core dagegen selbst mit.

```text
HOST / Gesamtsystem
  ├── physische Disks + Mounts   (fileSystems."/mnt/ssd", "/mnt/hdd")   ← Host
  └── mergerfs (optional, Tier-Pool)                                    ← Host
        │  (final gemergte Pfade)
        ▼
mediNix-core
  ├── systemd.tmpfiles  → logische Struktur (2775, Gruppe media)        ← Flake
  └── mediNix-mover     → Tier-B (SSD) → Tier-C (HDD)                   ← Flake (REAL)
```

- **Pfade / Backends** — REAL: `storage.mediaRoot`, `storage.metadataDir`,
  `storage.downloadDir` und optional `storage.backends.hot` / `.cold`.
  `57-maintenance/570-storage.nix` legt die Verzeichnisstruktur per
  `systemd.tmpfiles` an (Modus **2775**, SetGID, Gruppe `media`), damit
  Nachbardienste schreiben können.
- **Mover** — REAL (im Repo, **nicht** host-seitig): `54-processing/543-mover.nix`
  (`mediNix-mover.service`). Trigger ist `systemd.path` (`PathChanged` auf
  `stagingDir`) plus Sicherheits-Timer `OnUnitInactiveSec = 8h` — **kein
  Calendar-Takt**, damit die HDDs schlafen. Verschiebt nur Whitelist-Endungen
  (`mover.mediaExtensions`), > 50 MB, älter 5 min, mit `lsof`-Sperre,
  Atomar-Publish über `.staging_mover` und `flock`-Überlappungsschutz.
- **mergerfs** — COMPOSITION BOUNDARY (optional): Läuft **host-seitig**, NICHT im
  Modul (Portabilität). Nur im Tiered-Modus (`backends.hot` / `.cold`) erzeugt
  der Flake MergerFS-Pools je Medientyp; im Simple-Modus (`backends = {}`) gibt
  es keinen Pool. Trade-off beachten: `docs/arch/ARCH-50-architecture-blueprint.md`
  verwarf mergerfs historisch (Verzeichnis-Listing weckt alle HDDs). Ein
  Beispiel-Stand steht in `docs/examples/mergerfs-tiering.nix`.
- **minFreeGb** — INVARIANTE (nicht mehr offen): Option `medinix.mover.minFreeGb`
  (Default **20**, GB), **global** für das eine `stagingDir` → `archiveDir`-Paar.
  Durchgesetzt wird sie **zur Laufzeit** im Skript (`MIN_FREE_KB =
  minFreeGb × 1024²`, `df -Pk`-Vergleich), nicht per Eval-Assertion. Semantik von
  `0`: `FREE_KB >= 0` ist immer wahr → der Mover wird nie aktiv (No-op). Bei
  `mode = "off"` ist er ganz inaktiv.

## Storage-Contract und Tiering (PMS-Prinzipien, ohne ZFS)

mergerfs und das **Mounten** der Platten gehören dem **Host** (Composition Boundary, ADR-570); mediNix bringt den logischen Contract und den Mover.

- `storage.mediaRoot`, `storage.metadataDir`, `storage.downloadDir`, optional `storage.backends.hot` / `.cold`.
- `57-maintenance/570-storage.nix` legt die Struktur per `systemd.tmpfiles` an (Modus **2775**, SetGID, Gruppe `media`).
- `medinix.mover.minFreeGb` (Default 20) gilt global für das `stagingDir → archiveDir`-Paar und wird zur **Laufzeit** im Skript erzwungen (nicht per Eval-Assertion).

**Tiering:** Tier-B (SSD) = Staging/App-Daten, Tier-C (HDD) = Medien-Archiv. Der Mover (`54-processing/543-mover.nix`) ist event-getrieben (`systemd.path`) statt Cron, damit die HDDs schlafen: nur Whitelist-Endungen, > 50 MB, älter 5 min, mit `lsof`-Sperre, atomar über `.staging_mover` und `flock`-Überlappungsschutz.

**mergerfs** ist optional und host-seitig, nur im Tiered-Modus (`storage.backends.hot`/`.cold`); im Simple-Modus kein Pool. Historisch verworfen, weil ein Verzeichnis-Listing alle HDDs weckt (`docs/arch/ARCH-50-architecture-blueprint.md` — Historie, nicht Sollstand).

## Referenzen

- `57-maintenance/570-storage.nix` — tmpfiles-Struktur / optionale MergerFS-Pools
- `54-processing/543-mover.nix` — der Mover (Trigger, Bremse, Sicherungen)
- `docs/adr/ADR-570-storage-tiering-mergerfs.md` — physisch (Host) vs. logisch (Flake)
- `docs/ADMIN-HANDOFF.md` §3a/§3b — Mover-Handoff + mergerfs-Beispiel (host-seitig)
