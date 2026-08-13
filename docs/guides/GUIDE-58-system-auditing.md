---
id: "GUIDE-58-system-auditing"
title: "GUIDE 5800 system auditing"
domain: 58
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - audit
  - observability
links:
  adr: ""
  repo-harvest: ""
---
# 🔍 System Auditing: Die Dendriten visualisieren

Ein Aviation-Grade System muss transparent sein. Wir nutzen NixoScope, um die Modul-Abhängigkeiten sichtbar zu machen.

## 🚀 Warum Auditing?
- **Komplexitäts-Kontrolle:** Erkennt sofort, wenn das Dendritische Pattern durch zu viele Quer-Importe verwässert wird.
- **Fehlersuche:** Zeigt genau, welches Modul eine bestimmte Option definiert oder überschreibt.

## 🛠️ Anwendung (SRE Tor 5 Check)
Um den aktuellen System-Graph zu generieren:
`nix run github:giomf/nixoscope -- --option "flake.modules"`

## 🛡️ SRE-Integrität
Regelmäßige Audits mit NixoScope stellen sicher, dass die **Dendritische Integrität** gewahrt bleibt und keine monolithischen Strukturen "durch die Hintertür" eingeführt werden.
