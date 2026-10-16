---
id: "GUIDE-55-perfect-media-server"
title: "GUIDE 55 — Perfect Media Server: Storage-Tiering (SSD→HDD)"
domain: 55
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - media
  - playback
links:
  adr: ""
  repo-harvest: ""
---
# 📚 Perfect Media Server: Storage & Tiering

Adaptiert die PMS-Prinzipien (Alex Kretzschmar / ironicbadger) — aber **ohne ZFS**
und mit klarer Host/Flake-Trennung.

mergerfs und das **Mounten** der Platten gehören dem **Host** (Composition Boundary,
ADR-570). mediNix-core bringt nur den logischen Contract **und** den Mover mit.

## 📁 Storage-Contract
- `storage.mediaRoot`, `storage.metadataDir`, `storage.downloadDir`,
  optional `storage.backends.hot` / `.cold`.
- `57-maintenance/570-storage.nix` legt die Struktur per `systemd.tmpfiles` an
  (Modus **2775**, SetGID, Gruppe `media`).
- `medinix.mover.minFreeGb` (Default 20) gilt **global** für das
  `stagingDir → archiveDir`-Paar und wird zur **Laufzeit** im Skript erzwungen
  (nicht per Eval-Assertion).

## 🗄️ Tiering
- **Tier-B (SSD):** Staging / App-Daten.
- **Tier-C (HDD):** Medien-Archiv.
- **Mover (`54-transfer/543-mover.nix`):** event-getrieben (`systemd.path`) statt
  Cron, damit die HDDs schlafen; nur Whitelist-Endungen, > 50 MB, älter 5 min, mit
  `lsof`-Sperre, atomar über `.staging_mover` und `flock`-Überlappungsschutz.

## 🔎 mergerfs
Optional, **host-seitig**, nur im Tiered-Modus (`storage.backends.hot`/`.cold`);
im Simple-Modus kein Pool. Historisch verworfen, weil ein Verzeichnis-Listing alle
HDDs weckt (`docs/arch/ARCH-50-architecture-blueprint.md` — als Historie, nicht als
Sollstand).

Quellen: `docs/concepts/storage-mover.md`, `57-maintenance/README.md`,
`54-transfer/README.md`, `docs/ADMIN-HANDOFF.md` §3a/§3b.
