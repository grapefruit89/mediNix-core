---
id: "GUIDE-50-aspect-oriented"
title: "GUIDE 5000 aspect oriented"
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
# 🌳 Aspect-Oriented Dendritic Nix: Die Evolution

Wenn das Dendritische Pattern das Fundament ist, dann sind Aspekte die Leitungen im Haus.

## 🚀 Der Auto-Import Standard (`import-tree`)
Anstatt jedes Modul manuell zu importieren, nutzen wir Victor Borjas `import-tree`.
- **Regel:** Jede neue Datei im Ordner `modules/` wird automatisch Teil des Systems.
- **Vorteil:** Null Reibung beim Hinzufügen von Diensten.

## 🧩 Was sind Aspekte?
Ein Aspekt ist eine Funktion, die sich durch das gesamte System zieht (Cross-Cutting Concern).
- **Beispiel:** Der Aspekt "SRE-Monitoring" fügt jedem Dienst automatisch einen Prometheus-Exporter hinzu, ohne den Code des Dienstes zu ändern.

## 🛡️ Maintainability
Durch die Trennung von Aspekten bleibt die Logik eines Dienstes (z.B. Caddy) sauber von der Infrastruktur-Logik (z.B. Backup-Strategie).
