---
id: "GUIDE-50-pattern-mining"
title: "GUIDE 50 — Pattern Mining: aus Upstream lernen"
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
# 🎨 Pattern Mining: aus Upstream lernen

Wir kopieren keine Software, wir extrahieren **Struktur**. Der Fundus liegt in
`docs/patterns/` (z. B. `PATTERN-51-caddy.md`, `PATTERN-51-xcaddy.md`,
`PATTERN-58-sre-nixoscope.md`).

## 🚀 Methode
1. **Identifikation** — Upstream-Repo mit eleganter Lösung.
2. **Dekonstruktion** — `options`, `lib` und Modul-Struktur ansehen, **nicht** die
   Funktion.
3. **Abstraktion** — das Struktur-Prinzip in ein eigenes Modul überführen.

## 🏛️ Spur der Herkunft
Jedes übernommene Muster hinterlässt eine belegbare Spur:
- Das Modul nennt seine Quellen (`sources.upstream` / `sources.repo`), geprüft von
  `scripts/check_sources.py`.
- Der Registry-Eintrag verweist über ADR-0001 auf das Quell-Repo
  (`docs/adr/ADR-0001-source-repository-registry.md`).

Anker: **Mikado Method** / **Strangler Fig** (Refactor im Bestand statt Neubau) —
`docs/TERMINOLOGY.md`.

Quellen: `docs/patterns/`, `docs/UPSTREAM-SOURCES.md`, ADR-0001.
