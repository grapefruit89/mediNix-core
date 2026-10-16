---
id: "GUIDE-50-pragmatic-dendritic"
title: "GUIDE 50 — Pragmatische Dendritik: eine Datei pro Dienst"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# 🌳 Pragmatische Dendritik: eine Datei pro Dienst

Ordner dienen der Orientierung, Dateien der Vollständigkeit.

## 🧩 Self-Contained-Regel
Ein Dienstmodul erklärt **alles** selbst:

1. **Core:** `medinix.<name>.enable = true;`
2. **Runtime-Identität:** Eintrag in `lib/registry.nix` (Port = UID = num × 10).
3. **Ingress:** `medinix.ingress.vhosts."<name>".accessGroup = "...";`
4. **Secrets:** eigener `LoadCredentialEncrypted`-Pfad (versiegelt).

Kein Dienst trägt seine Belange in eine zentrale Datei ein. 511/513/515/518 kennen
**keine** Programmnamen — sie konsumieren das Manifest.

## 🛡️ Vorteil: Null Streuung
Dienst entfernen = Modul **+** Registry-Eintrag entfernen. Keine Leichen in einer
zentralen Caddy- oder Firewall-Datei.

## ⚠️ Anti-Pattern
`services.caddy.virtualHosts` von Hand schreiben — registriere einen vHost, 511
rendert ihn.

Quellen: `51-ingress/510-ingress-SERVICE.md`, Root-`README.md`,
`docs/TERMINOLOGY.md`.
