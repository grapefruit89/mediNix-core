---
id: "GUIDE-50-aspect-oriented"
title: "GUIDE 50 — Aspect-Oriented: Auto-Import & Querschnitts-Aspekte"
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
# 🌳 Aspect-Oriented Dendritic Nix

Zwei Ideen halten das Repo flach: **Auto-Import** und **Aspekte**.

## 🚀 Auto-Import statt Import-Liste
`default.nix` liest jedes `XX-domain/NNN-*.nix` selbst ein
(`builtins.readDir` + `lib.pipe`, **keine** hartkodierte Import-Liste):

- Eine neue Datei im Muster `NNN-<slug>.nix` wird automatisch Teil des Systems.
- Dateien mit `_`-Präfix werden übersprungen (Entwürfe).
- Es gibt **kein** `import-tree`-Input — der Mechanismus ist nativ in `default.nix`.

Quelle: `default.nix` (Auto-Import-Block), `docs/CONVENTIONS.md` §1.

## 🧩 Was ist ein Aspekt?
Ein Aspekt ist ein Querschnittsthema, das **neben** den Diensten lebt statt in jedem Dienst:

- `59-guardrails/591-cross-domain.nix` — domänenübergreifende Assertions.
- `58-observability/585-exporters.nix` — Prometheus-Exporter aus dem Manifest.
- `lib/*` — Engine, Registry, Contract, Hardening-Profile.

Faustregel: Der Dienst erklärt **sich selbst** (Manifest + `medinix.ingress.vhosts`),
der Aspekt konsumiert diese Beschreibung. Kein Dienstcode wird für ein
Querschnittsthema angefasst.

Quellen: `docs/TERMINOLOGY.md` (Anker Separation of Concerns / Defense in Depth),
`51-ingress/510-ingress-SERVICE.md`.
