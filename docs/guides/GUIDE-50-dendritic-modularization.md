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
| `54-processing` | SABnzbd, Mover (SSD→HDD) |
| `55-playback` | Jellyfin, Audiobookshelf, Navidrome |
| `56-exposition` | Seerr |
| `57-maintenance` | Storage, sqlite-wal, Backup, Provisioning, Drift |
| `58-observability` | ntfy, Gatus, runtime-guard, disk-health |
| `59-guardrails` | Cross-Domain-Assertions |

## 🛡️ Regel
Neue Datei = neuer Dendrit. Kein zentrales `caddy.nix`, keine zweite Import-Liste.
Die Ordnerregel (≥ 3 Dateien, mit Ausnahmen für `NN-…/`) prüft
`docs/agents/shared/scripts/folder_lint.sh` in `order-lint`.

Quellen: `docs/CONVENTIONS.md`, Root-`README.md`, `docs/TERMINOLOGY.md` (ADR-0000).

## 🚀 Auto-Import statt Import-Liste

`default.nix` liest jedes `XX-domain/NNN-*.nix` selbst ein (`builtins.readDir` + `lib.pipe`, **keine** hartkodierte Import-Liste):

- Eine neue Datei im Muster `NNN-<slug>.nix` wird automatisch Teil des Systems.
- Dateien mit `_`-Präfix werden übersprungen (Entwürfe).
- Es gibt **kein** `import-tree`-Input — der Mechanismus ist nativ in `default.nix`.

## 🧩 Was ist ein Aspekt?

Ein Aspekt ist ein Querschnittsthema, das **neben** den Diensten lebt statt in jedem Dienst:

- `59-guardrails/591-cross-domain.nix` — domänenübergreifende Assertions.
- `58-observability/585-exporters.nix` — Prometheus-Exporter aus dem Manifest.
- `50-core/*` — Engine, Registry, Contract, Hardening-Profile.

Faustregel: Der Dienst erklärt **sich selbst** (Manifest + `medinix.ingress.vhosts`), der Aspekt konsumiert diese Beschreibung. Kein Dienstcode wird für ein Querschnittsthema angefasst.

## 🧩 Self-Contained-Regel (eine Datei pro Dienst)

Ein Dienstmodul erklärt **alles** selbst:

1. **Core:** `medinix.<name>.enable = true;`
2. **Runtime-Identität:** Eintrag in `50-core/registry.nix` (Port = UID = num × 10).
3. **Ingress:** `medinix.ingress.vhosts."<name>".accessGroup = "...";`
4. **Secrets:** eigener `LoadCredentialEncrypted`-Pfad (versiegelt).

Kein Dienst trägt seine Belange in eine zentrale Datei ein. 511/513/515/518 kennen **keine** Programmnamen — sie konsumieren das Manifest.

**Vorteil Null Streuung:** Dienst entfernen = Modul **+** Registry-Eintrag entfernen. Keine Leichen in einer zentralen Caddy- oder Firewall-Datei.

**Anti-Pattern:** `services.caddy.virtualHosts` von Hand schreiben — registriere einen vHost, 511 rendert ihn.

Quellen: `default.nix`, `51-ingress/510-ingress-SERVICE.md`, `docs/TERMINOLOGY.md`.
