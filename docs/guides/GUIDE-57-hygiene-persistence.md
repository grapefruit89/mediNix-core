---
id: "GUIDE-57-hygiene-persistence"
title: "GUIDE 57 — Hygiene & Persistence: stateDir + tmpfiles"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# 🧹 Hygiene & Persistence: stateDir + tmpfiles

Kein Impermanence-Framework, kein `/persist`. Persistenz ist **pro Dienst**
deklariert.

## 📁 State-Verzeichnisse
- Jeder Dienst bekommt sein eigenes `stateDir` (siehe Service Map in
  `docs/INDEX.md`), erzeugt von `lib/service-factory.nix` + `systemd.tmpfiles`
  aus `lib/registry.nix`.
- `57-maintenance/570-storage.nix` legt die Storage-Struktur per tmpfiles an
  (Modus **2775**, SetGID, Gruppe `media`) — Nachbardienste können schreiben.

## 🧰 Hygiene-Jobs (57-maintenance)
- `571-sqlite-wal.nix` — WAL erzwingen + periodisch `VACUUM`/`ANALYZE`; liest die
  `StateDirectory`-Pfade **dynamisch** aus `registry.nix`.
- `576-backup.nix` / `579-backup-ssh.nix` — Backups.
- `577-drift-detection.nix` / `578-orphan-cleanup.nix` — Drift und Verwaistes.

## 🛡️ Purity-Regel
Ausschluss von totem Code. Nie verdrahtete Module werden markiert bzw. nach
`docs/audit/<jahr-monat>/` archiviert (Chesterton's Fence) — nichts wird
stillschweigend gelöscht.

Quellen: `57-maintenance/README.md`, `54-transfer/README.md`,
`docs/CONVENTIONS.md`, `docs/TERMINOLOGY.md`.
