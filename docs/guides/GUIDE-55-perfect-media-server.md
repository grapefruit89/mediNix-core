---
id: "GUIDE-55-perfect-media-server"
title: "GUIDE 5500 perfect media server"
domain: 55
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - media
  - playback
links:
  adr: ""
  repo-harvest: ""
---
# 📚 The PMS Standard: Storage & Media Mastery

Basierend auf den Prinzipien von Alex Kretzschmar (@ironicbadger) bauen wir deinen Tower zum "Perfect Media Server" aus.

## 🏛️ Das ZFS-Fundament
Wir verabschieden uns von Unraid-Arrays und setzen auf **ZFS native**.
- **Daten-Integrität:** Schutz vor Bit-Rot durch Checksums.
- **Snapshots:** Atomare Backups deines kompletten Medien-Stacks.
- **Performance:** ARC-Caching für blitzschnelle Datei-Zugriffe.

## 📁 Die Storage-Hierarchie (Aviation-Grade)
1.  **Tier A (NVMe):** OS, Flakes und Sops-Secrets.
2.  **Tier B (SSD):** App-Daten (PostgreSQL, Plex-Datenbank).
3.  **Tier C (HDD):** Massenspeicher für Medien (ARR-Storage).

## 🧩 Modul-Design
Jeder Medien-Dienst (Sonarr, Radarr etc.) nutzt das **Dendritic Pattern v8.0** und bezieht seine Pfade aus einer zentralen `storage.nix` (SSoT).