---
id: "ADR-543"
title: "Cold-Archive-Tiering: Piggyback-Mover mit I/O-Contention-Schutz"
status: active
complexity: 3
last_reviewed: 2026-11-26
links:
  adr: ADR-5000 (native services), ADR-570 (Storage-Tiering)
---

# ADR-543: Cold-Archive-Tiering - Piggyback-Mover mit I/O-Contention-Schutz

## Kontext
Der einzige legitime Grund für den Mover in einem Tiered-Setup ist **Write-Batching**: mehrere Importe am Tag bündeln und erst wegschreiben, wenn die Archiv-HDD ohnehin läuft und gerade nicht gestreamt wird. Ein naiver Mover weckt bei jedem Download-Event die HDD, zerreisst Releases in Einzeldateien (`.mkv` auf HDD, `.srt`/`.nfo` auf SSD) oder verursacht durch Vollgas-Writes Head-Thrashing während Jellyfin-Streams.

## Entscheidung
- **Strikte Video-Whitelist statt Junk-Transfer:** Der Mover (`543-mover.nix`) verschiebt ausschließlich große Videocontainer (`.mkv`, `.mp4`, `.avi`, `.m4v`, `.ts` mit `-size +100M`, konfigurierbar via `medinix.mover.minFileSize`) unter Beibehaltung der Verzeichnisstruktur. Klein- und Begleitdateien (`.nfo`, `.txt`, `.sfv`, `.srr`, `.jpg`, `.png`, `.log`, `.parts`, Samples `< 100M`) sowie **Audiobooks** (`moveAudiobooks = false` Default) verbleiben dauerhaft auf Tier-B (SSD); MergerFS vereint beide Tiers nahtlos in derselben Ordneransicht.
- **4-Gate-Pipeline (strikte Reihenfolge gegen unnötige HDD-Wakes):**
  1. **Gate 1 (Pfade & Mount-Schutz):** `stagingDir != archiveDir`, Ziel-Mountpoint != `/`, Ziel ist physischer Mount (`!= fuse.mergerfs`). 0 HDD-I/O.
  2. **Gate 2 (Füllstand & Vorrat auf SSD):** `free >= minFreeGb` oder keine Kandidaten auf SSD -> sofort `exit 0`. 0 HDD-I/O.
  3. **Gate 3 (Piggybacking via `hdparm -C`):** Bei `free >= criticalFreeGb` wird die HDD **niemals** geweckt; nur wenn `active/idle` gemeldet wird, geht es weiter. Erst unterhalb `criticalFreeGb` (Fail-Closed ENOSPC-Schutz) erfolgt ein geloggter `WAKE`.
  4. **Gate 4 (I/O-Contention / Playback-Schutz):** Prüft `/sys/block/<disk>/stat` (`in_flight > 0` oder Lese-Sektoren-Delta seit letztem Tick > `idleReadThresholdKb`). Dreht die HDD (`active/idle`), aber Jellyfin liest aktiv, verschiebt der Mover den Lauf auf das ruhige Spindown-/Pufferfenster nach dem Film.
- **I/O-Priorisierung:** `IOSchedulingClass = "idle"` (`ionice -c 3`) + `Nice = 19`, damit Lesezugriffe im Kernel-Scheduler jederzeit Vorrang haben.
- **Monotoner Piggyback-Ticker statt `PathChanged`:** `systemd.timers.mediNix-mover` (`OnUnitInactiveSec = piggybackInterval`, Default `5m`) ohne `cron` und ohne `systemd.path`-Sturm (`StartLimitBurst`-Ausfälle beim SABnzbd-Entpacken).

## Datenintegritaet & Poka-Yoke
- **Fail-Closed Optionen:** `stagingDir` und `archiveDir` haben `default = null` und Compile-Time-Assertions verbieten `backends.hot`/`.cold`-Wurzeln sowie Überlappung mit `storage.metadataDir`.
- **Atomares Veroeffentlichen außerhalb der Union:** Kopie mit `cp -a --reflink=auto` in `$ARCHIVE_MNT/.mover-tmp` (gleiches XFS, außerhalb des MergerFS-Branches), `sync -f` vor `mv -T`, erst danach `rm -rf` der Quelle.
- **Kein Subshell-Trap-Bug:** Iteration per Prozesssubstitution `< <(find ... | sort -z)`, sodass `trap cleanup EXIT INT TERM` die aktive Temp-Kopie im Parent sieht; Altlasten in `.mover-tmp` werden erst nach Passieren aller Gates abgeräumt (0 HDD-Wake).

## Konsequenzen
- Hauswirtschaft weckt die HDD im Normalbetrieb niemals (nur nutzerinitiierte Wiedergabe/Importe wecken; Ausnahme `criticalFreeGb`).
- Während laufender Jellyfin-Wiedergabe bleibt der Mover still; das ideale Fenster ist das Spindown-Verzögerungsfenster nach Filmende.
