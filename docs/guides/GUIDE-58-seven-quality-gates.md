---
id: "GUIDE-58-seven-quality-gates"
title: "GUIDE 58 — Die Checks der Kette (order-lint & generierte Docs)"
domain: 58
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - observability
  - quality
links:
  adr: ""
  repo-harvest: ""
---
# ⚙️ Die Checks der Kette

Qualität ist maschinell: jeder Knoten der Kette hat einen **Check**
(`docs/CONVENTIONS.md` §Die Kette), ausgeführt in `order-lint` / `flake-check`.

| Kante | Check |
|---|---|
| Code → Manifest | `scripts/check_manifest_edge.py` |
| Code → ADR | `scripts/check_adrs.py` (Verweis auf Dateinamen = Fehler) |
| ADR → Index | `scripts/check_adrs.py` + `docs/adr/llm-index.json` |
| Docs → Generatoren | `gen_todo.py --check`, `gen_service_map.py --check`, `medinix-meta.py check-docs`, `docs/generate_index.py` |
| Skills → Sichtbarkeit | `scripts/link-skills.sh --dry-run` / `check_skills.py` |
| Skills → MCP | `scripts/check_skills.py` (`mcp: [...]` + `scripts/mcp-servers.txt`) |
| Korridor → Checks | `scripts/check_corridor.py` |
| NixOS-Idiome | `scripts/nixos_idiom_audit.py --p0-only` |

Dazu: `folder_lint.sh` (Ordnung), `check_sources.py`,
`check_banned_technologies.py`, `check_nixos_anchors.py` und `flake-check.yml`.

## 🛡️ Regel bei jedem Fund
**Fixen** — oder eine begründete Ausnahme in die jeweilige Allowlist eintragen.
Allowlists dürfen nur schrumpfen (Ratsche).

Quellen: `docs/CONVENTIONS.md` §Die Kette, `.github/workflows/order-lint.yml`.
