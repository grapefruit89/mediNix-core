# mediNix Storage-Architektur & Host-Schnittstelle (Das „Panzerband“)

> **Status:** Kanonische Architektur-Dokumentation  
> **Anchors:** `hardware-abstraction-layer`, `tiered-storage`, `separation-of-concerns`, `poka-yoke`  
> **Datum:** 2026-11-26

---

## 1. Die Kern-Idee: Ein einziges virtuelles Laufwerk (`MergerFS`)

Du musst in Jellyfin **niemals** zwischen SSD-Filmen und HDD-Filmen unterscheiden!

```
                    ┌─────────────────────────┐
                    │  Jellyfin / Seerr / UI  │
                    └────────────┬────────────┘
                                 │
           Greift AUSSCHLIESSLICH zu auf: /srv/media
                                 │
                    ┌────────────▼────────────┐
                    │    MergerFS (Union)     │
                    │   /srv/media/movies     │
                    │   /srv/media/series     │
                    └────────────┬────────────┘
                                 │
            ┌────────────────────┴────────────────────┐
            ▼                                         ▼
   ┌──────────────────┐                      ┌──────────────────┐
   │  Branch 1 (SSD)  │                      │  Branch 2 (HDD)  │
   │  /mnt/ssd/media  │                      │  /mnt/hdd/media  │
   └──────────────────┘                      └──────────────────┘
    (Neue Downloads,                          (Alte Dickschiffe,
     Hörbücher, Churn)                         MKVs im Spindown)
```

### Wie das im Alltag funktioniert:
1. **Zusammenhängende Ansicht:**  
   MergerFS verschmilzt `/mnt/ssd/media` und `/mnt/hdd/media` zu `/srv/media`.  
   Jellyfin sieht nur `/srv/media/movies`. Ob der Film auf der SSD oder HDD liegt, ist für Jellyfin zu 100% unsichtbar!
2. **Schreiben auf die SSD (`category.create=ff`):**  
   Wenn Sonarr/Radarr einen Film importiert, schreibt es nach `/srv/media/movies/Film.mkv`. MergerFS leitet neue Schreibzugriffe immer auf die erste Branch (**die SSD**) um.
3. **Der Mover im Hintergrund:**  
   Verschiebt der Mover den Film später von `/mnt/ssd` nach `/mnt/hdd`, bleibt der Pfad `/srv/media/movies/Film.mkv` für Jellyfin **vollkommen identisch und unterbrechungsfrei**!

---

## 2. Die 3 physischen Tiers (Hardware-Mapping)

| Tier | Hardware | Mountpoint (Host) | mediNix-Nutzung | Spindown-Verhalten |
|---|---|---|---|---|
| **Tier 1 (State)** | NVMe SSD | `/var/lib/medinix/` | **OS, Appdata, Metadaten:** SQLite WAL, Cover, Poster, Thumbnails. | Lautlos, 0ms Reaktionszeit, 0 HDD-Zugriff beim Browsen. |
| **Tier 2 (Cache/Scratch)** | SATA SSD (~250 GB) | `/mnt/ssd/` | **Download-Workhorse & Audiobooks:** SABnzbd Ingestion (Entpacken, Par2) + Hörbücher (tausende kleine MP3s). | Schützt HDDs vor Schreiblast und Fragmentierung. |
| **Tier 3 (Archive)** | SATA HDD(s) | `/mnt/hdd/` (JBOD, XFS) | **Kaltablage für Dickschiffe:** Ausschließlich Mediendaten (`.mkv`, `.mp4`). | **Schläft 95% der Zeit im Spindown.** |

---

## 3. Die Host-Schnittstelle (Was der Host bereitstellt)

Gemäß der `separation-of-concerns`-Invariante besitzt mediNix-core **keine** Festplatten oder Partitionen. Der Host stellt exakt 3 Dinge bereit:

```nix
# Auf dem Host (z. B. in /etc/nixos/configuration.nix):

# 1. SSD Mount (XFS, noatime)
fileSystems."/mnt/ssd" = {
  device = "/dev/disk/by-label/FAST_SSD";
  fsType = "xfs";
  options = [ "noatime" ];
};

# 2. HDD JBOD Mount (XFS, noatime, nofail, by-label)
fileSystems."/mnt/hdd" = {
  device = "/dev/disk/by-label/COLD_HDD1";
  fsType = "xfs";
  options = [ "noatime" "nofail" "x-systemd.device-timeout=10s" ];
};

# 3. MergerFS Union (Die unsichtbare Schiene für Jellyfin)
fileSystems."/srv/media" = {
  device = "/mnt/ssd/media:/mnt/hdd/media";
  fsType = "fuse.mergerfs";
  options = [
    "defaults"
    "allow_other"
    "use_ino"
    "category.create=ff"   # Neue Dateien landen IMMER auf der SSD
    "moveonenospc=mfs"      # Weicht bei voller SSD automatisch aus
    "minfreespace=20G"      # Mindestens 20 GB Puffer
    "cache.readdir=true"    # Verzeichnisbäume im RAM (ersetzt cache_dirs!)
  ];
};
```

---

## 4. Der intelligente Mover & die Filter-Regeln

### Filter-Regel (Keine Winz-Dateien auf die HDD!):
* **Erlaubt auf HDD:** Große Mediendateien (`.mkv`, `.mp4`, `.avi`, `.m4v`, `.ts`).
* **Verboten auf HDD:** Textdateien, NFOs, SFVs, Samples, Unrar-Reste (`.nfo`, `.txt`, `.sfv`, `.jpg`, `.png`, `.log`).
* **Audiobooks:** Bleiben standardmäßig auf Tier 2 (SSD), es sei denn, sie werden explizit für Tier 3 freigegeben.

### Das Piggybacking-Prinzip mit Contention-Schutz:
1. **Schlaf-Check:** Schläft die HDD? $\rightarrow$ Mover macht GAR NICHTS (`exit 0`).
2. **Streaming-Check:** Liest Jellyfin gerade aus der HDD? $\rightarrow$ Mover bricht ab (`defer`), um Ruckler zu verhindern!
3. **Windschatten:** Erst wenn die Platte noch dreht, aber kein Lesezugriff stattfindet, schiebt der Mover mit `ionice -c 3` (niedrigste I/O-Priorität) die Dateien rüber.
