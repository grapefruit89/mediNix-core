---
id: "GUIDE-50-stick-ready-deployment"
title: "GUIDE 5000 stick ready deployment"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# 🚀 Stick-Ready: Das Zero-Touch Deployment

Das Ziel von mynixos ist: **Stick rein, System fertig.** Keine manuellen Einstellungen, keine Caddy-Frickelei.

## 🛠️ Die Trinität des Deployments
1.  **Disko:** Erstellt die Partitionen (ZFS/ext4) automatisch aus der Nix-Konfig.
2.  **Srvos:** Wendet sofort alle Server-Härtungen und Optimierungen an.
3.  **Nixos-Anywhere:** Schiebt das fertige System via SSH auf den Tower.

## 🛡️ Native-First Prinzip
Wir bevorzugen native NixOS-Dienste (wie `services.caddy.enable = true;`) gegenüber Docker. 
- **Grund:** Volle deklarative Kontrolle bis in die kleinste Config-Zeile.
- **Effizienz:** Weniger Overhead, direkter Systemd-Zugriff.

## 🧩 Der Workflow
1.  Änderung in `/home/mynixos/` vornehmen.
2.  `nixos-rebuild switch --flake .#tower` (oder via nixos-anywhere).
3.  Fertig. Das System spiegelt exakt den Code wider.
