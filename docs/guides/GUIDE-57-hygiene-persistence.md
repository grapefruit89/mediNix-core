---
id: "GUIDE-57-hygiene-persistence"
title: "GUIDE 5700 hygiene persistence"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# 🧹 Hygiene & Persistence: Das Impermanence Prinzip

In einem Aviation-Grade System ist das Root-Dateisystem (`/`) flüchtig. Alles, was nicht explizit gespeichert werden soll, wird bei jedem Reboot gelöscht.

## 🚀 Warum Impermanence?
- **Anti-System-Rot:** Verhindert das Ansammeln von Datenmüll.
- **Deklarative Sicherheit:** Alles, was persistiert werden soll, MUSS im Nix-Code stehen.

## 📁 Persistence Mapping
Wir nutzen den Ordner `/persist/` (auf ZFS oder SSD), um wichtige Daten zu halten.
- `/persist/var/lib/couchdb`
- `/persist/home/grapefruit89`

## 🧩 Modul-Integration
Jeder Dendrit (Dienst) deklariert seine eigenen Persistenz-Pfade. 
