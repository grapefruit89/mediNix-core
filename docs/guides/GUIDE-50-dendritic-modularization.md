---
id: "GUIDE-50-dendritic-modularization"
title: "GUIDE 5000 dendritic modularization"
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
# 🌳 Dendritische Modularisierung: Die Flache Bibel

Wir folgen dem Prinzip der maximalen Übersichtlichkeit: **Strikte flache Hierarchie.**

## 📁 Die Goldene Ordnerstruktur (v8.0)
Jede Datei in mynixos ist ein Top-Level Modul innerhalb eines fest definierten Layers. Maximale Tiefe: 1 Ebene unter modules/.

### /home/mynixos/
- `flake.nix` (Einstieg)
- `hosts/q958.nix` (Hardware & Enable-Flags)
- `modules/00-core/` (OS-Fundament)
- `modules/10-gateway/` (Erreichbarkeit)
- `modules/20-data/` (Datenbanken)
- `modules/30-services/` (Apps)
- `modules/40-media/` (Entertainment)
- `modules/50-knowledge/` (Wissen)
- `modules/80-monitoring/` (SRE)
- `modules/90-policy/` (Regeln)

## 🧩 Keine Unterordner
Innerhalb der Layer-Ordner liegen nur direkt .nix Dateien. Keine weiteren Verzeichnisse, keine komplexen Verschachtelungen.