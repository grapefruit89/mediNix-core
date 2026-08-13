---
id: "GUIDE-50-pragmatic-dendritic"
title: "GUIDE 5000 pragmatic dendritic"
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
# 🌳 Die Pragmatische Dendritische Synthese

Wir kombinieren die Übersichtlichkeit einer **Layer-Struktur** mit der Autonomie des **Dendritic Patterns**.

## 🏛️ Das Organisations-Prinzip
Ordner (Layer) dienen der **Orientierung**, Dateien (Dendriten) dienen der **Vollständigkeit**.

## 🧩 Die "Self-Contained" Regel
Jedes Modul (z.B. `40-media/jellyfin.nix`) ist dafür verantwortlich, alle seine Belange selbst zu deklarieren:
1.  **Core-Dienst:** `services.jellyfin.enable = true;`
2.  **Hardware:** GPU-Passthrough / iHD-Driver.
3.  **Ingress:** Deklaration des eigenen Caddy-VirtualHosts.
4.  **Security:** Eigene Sops-Secrets.

## 🛡️ Vorteil: Null Streuung
Wenn wir Jellyfin entfernen wollen, löschen wir **eine Datei**. Es bleiben keine "Leichen" in einer zentralen `caddy.nix` oder `firewall.nix` zurück.

## ⚙️ Technische Umsetzung
Wir nutzen `flake-parts` und `import-tree`, um alle Dateien in allen Layer-Ordnern automatisch einzulesen. NixOS mergt die Konfigurationen (z.B. alle `virtualHosts`) während der Evaluation zusammen.