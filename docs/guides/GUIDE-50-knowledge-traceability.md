---
id: "GUIDE-50-knowledge-traceability"
title: "GUIDE 50 — Knowledge Traceability: Quellen, ADRs, Ledger"
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
# 📚 Knowledge Traceability: jede Aussage hat eine Quelle

Drei Spuren, alle maschinell prüfbar:

1. **Upstream-Quellen je Modul** — `sources.upstream` + `sources.repo`, erzwungen
   von `scripts/check_sources.py`; Übersicht in `docs/UPSTREAM-SOURCES.md`,
   offene Fälle in `scripts/sources-baseline.txt` (Ratsche, nur schrumpfend).
2. **ADR-Verweise im Modul-Header** — jeder `adr:`-Verweis zeigt auf eine
   existierende ADR-ID (`scripts/check_adrs.py`; ein Verweis auf den *Dateinamen*
   ist immer ein Fehler). Altfälle: `scripts/adr-refs-allowlist.txt`.
3. **Audit-Ledger** — `docs/AUDIT-LEDGER.md` hält je Befund Quelle **und** Rollback;
   Aussagen sind als **REAL / DESIGN / GONE** markiert (so auch in den
   Concept-Seiten `docs/concepts/*`).

## 🛡️ Anti-Halluzinations-Schutz
Ein Wert ohne Quelle und ohne Zeitbezug ist kein Beleg, sondern eine Behauptung —
siehe Root-`AGENTS.md` (Verifikations-Disziplin, Phasen 1–4).

## 🧩 YAML-Header
Jedes Wissensdokument beginnt mit einem YAML-Header. Für Modul-/Struktur-Dokumente
prüft `scripts/nixmeta_check.py` die Kernfelder `id`, `title`, `domain`,
`last_reviewed` (Format `YYYY-MM-DD`).

Quellen: `docs/CONVENTIONS.md` §Die Kette, `docs/UPSTREAM-SOURCES.md`,
`docs/AUDIT-LEDGER.md`.
