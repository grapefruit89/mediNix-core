---
id: "GUIDE-58-system-auditing"
title: "GUIDE 58 — System-Auditing: eval-Checks & NIXMETA-Graph"
domain: 58
status: active
complexity: 2
last_reviewed: 2026-10-17
tags:
  - audit
  - observability
links:
  adr: ""
  repo-harvest: ""
---
# 🔍 System-Auditing: was definiert was?

Transparenz entsteht aus **Checks** und dem **generierten Modul-Graph**.

## 🛠️ Werkzeuge
- **Eval-Checks:** `nix flake check` evaluiert alle Assertions und Negativtests
  (Port-Riegel, Token-Trennung, vHost-Auflösung, UID-Kette …).
- **NIXMETA-Header:** jedes Modul trägt Metadaten; `medinix-meta.py` erzeugt daraus
  die `AGENTS.md` je Domäne inkl. Module Map, Requires und Mermaid-Abhängigkeits-
  graph. Prüfen: `python 50-core/medinix-meta.py check-docs`.
- **Ordnungs-/Kanten-Checks:** `order-lint` (`docs/CONVENTIONS.md` §Die Kette).
- **Optionaler Graph:** `docs/patterns/PATTERN-58-sre-nixoscope.md` beschreibt den
  Einsatz von NixoScope zur Visualisierung der Modul-Abhängigkeiten.

## 📌 Regel
`*/AGENTS.md` ist **generiert** — nur oberhalb des `AUTO-GENERATED`-Markers von Hand
editieren; neu erzeugen mit `medinix-meta.py generate-docs`.

Quellen: `docs/CONVENTIONS.md`, `51-ingress/AGENTS.md` (generierter Graph),
`docs/patterns/PATTERN-58-sre-nixoscope.md`.
