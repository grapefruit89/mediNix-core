---
id: "GUIDE-50-dendritic-modularization"
title: "GUIDE 50 — Dendritische Modularisierung: die flache Dezimal-Struktur"
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
# 🌳 Dendritische Modularisierung: die flache Dezimal-Struktur

Strikte flache Hierarchie: **eine Ebene** unter dem Repo-Root.

## 📁 Die Struktur (ADR-0000)
- `<NN-domain>/<NNN-dienst>.nix`, z. B. `51-ingress/511-caddy.nix`.
- `default.nix` importiert jedes `NNN-*.nix` automatisch (`builtins.readDir`).
- Keine Unterordner in den Domänen-Ordnern.

## 🧩 Domänen (SSoT: Root-README + Service Map in `docs/INDEX.md`)
| Ordner | Rolle |
|---|---|
| `50-core` | Host-Baseline, Dezimal-Engine, Meta-Tooling |
| `51-ingress` | Reverse-Proxy, TLS, DNS, mDNS, OIDC, Landing |
| `52-security` | Core-Security, Credentials, VPN |
| `53-acquisition` | *arr (Sonarr, Radarr, Readarr, Lidarr, Prowlarr) |
| `54-transfer` | SABnzbd, Mover (SSD→HDD) |
| `55-playback` | Jellyfin, Audiobookshelf, Navidrome, Feishin |
| `56-exposition` | Seerr |
| `57-maintenance` | Storage, sqlite-wal, Backup, Provisioning, Drift |
| `58-observability` | ntfy, Gatus, runtime-guard, disk-health |
| `59-guardrails` | Cross-Domain-Assertions |

## 🛡️ Regel
Neue Datei = neuer Dendrit. Kein zentrales `caddy.nix`, keine zweite Import-Liste.
Die Ordnerregel (≥ 3 Dateien, mit Ausnahmen für `NN-…/`) prüft
`docs/agents/shared/scripts/folder_lint.sh` in `order-lint`.

Quellen: `docs/CONVENTIONS.md`, Root-`README.md`, `docs/TERMINOLOGY.md` (ADR-0000).
