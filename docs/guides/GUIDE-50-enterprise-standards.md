---
id: "GUIDE-50-enterprise-standards"
title: "GUIDE 50 — Enterprise-Standards: order-lint & fail-closed Checks"
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
# 🏢 Enterprise-Standards: Checks statt Handarbeit

Qualität ist im Repo nicht Prosa, sondern **CI**. `order-lint`
(`.github/workflows/order-lint.yml`) erzwingt die Regeln:

- `folder_lint.sh` — Ordnerregel ≥ 3 Dateien (Ausnahmen: `docs/CONVENTIONS.md` §1)
- `check_skills.py` — Skill-Form + MCP-Deklaration
- `check_adrs.py` — ADR-Formregel + `docs/adr/llm-index.json`
- `check_manifest_edge.py` — Registry → Manifest
- `check_sources.py` — jedes Modul nennt Upstream-Quellen
- `check_corridor.py` — Korridor-Muster (AB-Regeln)
- `check_nixos_anchors.py`, `check_banned_technologies.py`,
  `nixos_idiom_audit.py --p0-only`
- Generator-Frische: `gen_todo.py --check`, `gen_service_map.py --check`

Dazu `flake-check.yml` (`nix flake check`) und `docs-index.yml` (INDEX aktuell).

## 🛡️ Fail-closed
Alle Guardrails sind `config.assertions` — eine Fehlkonfiguration bricht den
**Build** (fail-closed), nicht den Betrieb.

## 📌 Stand (verifiziert in `flake.nix`)
Die Flake-Inputs sind nur `nixpkgs` und `flake-utils`. Es gibt **kein**
FlakeHub, **keinen** Magic-Nix-Cache und **keinen** flake-checker.

Quellen: `.github/workflows/`, `docs/CONVENTIONS.md` §Die Kette, `flake.nix`.
