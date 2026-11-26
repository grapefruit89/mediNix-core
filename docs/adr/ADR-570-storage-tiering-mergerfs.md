---
id: "ADR-570"
title: "Storage-Tiering: 3-Tier-Modell, XFS-JBOD & MergerFS-Vertrag"
status: active
complexity: 3
last_reviewed: 2026-11-26
links:
  adr: ADR-0000 (Dezimalrahmen/UPG), ADR-543 (Cold-Archive-Mover)
---

# ADR-570: Storage-Tiering - 3-Tier-Modell, XFS-JBOD & MergerFS-Vertrag

## Kontext
Zwei Ebenen: **physisch** (der Host mountet die Platten, `fileSystems."/mnt/hdd01"` …) und
**logisch** (die Medienablage, die alle Dienste gemeinsam nutzen: `mediaRoot`, `downloadDir`, `metadataDir`).

## Entscheidung

### 1. Dateisystem & JBOD (Tier 3)
- **XFS** als Workhorse fuer mechanische Medienplatten: Extent-B-Trees fuer 2-70 GB sequentielle Dateien, O(1)-`statfs`, kein `resize2fs -M`-Bedarf.
- **Kein RAID, kein ZFS, kein btrfs-COW:** Stirbt eine Platte im JBOD, sind ausschliesslich deren ganze Dateien weg; MergerFS liefert nahtlos den Restbestand.
- **Verbindliche Host-Mount-Optionen (`recommended.mountOptions.hdd`):**
  - `noatime`: verhindert atime-Schreibzugriffe beim Lesen nach 24h (kein unnoetiges Plattenaufwecken).
  - `/dev/disk/by-label/...`: niemals flüchtige `/dev/sdX`-Namen.
  - `nofail` + `x-systemd.device-timeout=10s`: ein fehlendes JBOD-Laufwerk blockiert niemals den Boot.

### 2. Geschaerftes 3-Tier-Modell (lebensdauer- statt geraetebasiert)
- **Tier 1 (NVMe — State):** OS, `/var/lib`, SQLite WAL, `metadataDir` (Jellyfin-Metadaten/Artwork mit `SaveArtworkIntoMovieFolders: false`, `*arr` MediaCover) -> **0 HDD-Wakes beim Browsen**.
- **Tier 2 (SATA SSD — Transient Scratch):** `downloadDir` (SABnzbd PAR2/Entpacken) + temporäres Staging vor Write-Batching.
- **Tier 3 (SATA HDD JBOD — Library):** Große MKVs (> 1-2 GB) **und statische Audiobooks** (`audiobooks` sind langlebige Bibliotheksdaten und gehoeren niemals in eine SSD-Drain-Zone).

### 3. Vereinfachung `570-storage.nix` & Poka-Yoke
- **Zentraler Schalter `storage.mode`:** Explizite Umschaltung zwischen `"single-disk"` (`backends = {}`) und `"tiered"` (erfordert strikt `{ hot; cold; }`).
- **Poka-Yoke-Riegel gegen HDD-Wakes:** `storage.metadataDir` und `storage.downloadDir` duerfen niemals auf `backends.cold` (Tier 3) zeigen (Compile-Time-Assertion).
- **Runtime Pre-Flight Check:** `medinix-storage-preflight.service` prueft beim Booten ueber `/sys/block/.../queue/rotational`, ob Metadaten/Scratch versehentlich auf mechanischen HDDs gemountet sind.
- Verzeichnisse (`movies`, `series`, `books`, `audiobooks`, `music`) mit Modus **2775** (`SetGID`, Gruppe `media` GID 5000).

### 4. MergerFS-Politik (`recommended.mountOptions.mergerfs`, ersetzt `cache_dirs`)
- `category.create=ff` (erste Branch = SSD zuerst; nicht `mfs`, sonst landen neue Downloads auf der schlafenden HDD).
- `moveonenospc=mfs`, `minfreespace=50G` (XFS B-Tree-Fragmentierung vermeiden).
- `cache.readdir=true`, `cache.entry=30`, `cache.negative_entry=30`, `cache.statfs=30`, `cache.symlinks=true`, `dropcacheonclose=true` ersetzen Userspace-`cache_dirs` im Kernel-Cache (ergänzt durch `EnableRealtimeMonitor: false` in Jellyfin und Ausschluss von `/mnt` in `updatedb`/`plocate`).
- **Caveat:** Out-of-Band-Verschiebungen des Movers (`B -> C`) invalidieren `cache.readdir` nicht sofort; im Mediabox-Betrieb unkritisch, da Jellyfin über Event-Push statt inotify auf dem Union-Tree aktualisiert wird.

## Konsequenzen
- Composition Boundary bleibt strikt gewahrt: der Host besitzt die physischen Mounts und die FUSE-Union, das Flake prueft Konsistenz und legt die Verzeichnisstruktur an.
- `cache.readdir`-Staleness nach Out-of-Band-Mover-Laeufen ist dokumentierter Trade-off.
