---
title: Storage & Mover
type: Concept
---
# Storage & Mover

**Concept — Architektur-Absicht / Composition Boundary, keine bewiesene Runtime-Eigenschaft.**

mediNix-core beansprucht **nicht**, die Storage-Infrastruktur zu besitzen. Es
braucht einen **Storage-Contract**; mergerfs und der Mover gehören dem Host /
Gesamtsystem.

```text
HOST / Gesamtsystem
  ├── Storage
  ├── mergerfs
  └── mover
        │  (final gemergte Pfade)
        ▼
50-mediNix  — sieht nur die finalen Pfade
```

Der Flake sagt also nicht „Ich betreibe mergerfs", sondern „Ich benötige einen
Storage-Contract". Das ist bewusst chamäleonfreundlich: derselbe Contract kann
später vom Gesamtsystem (20/30/50/60/70/80/90) bedient werden.

- **Path** — REAL: Alle Storage-Mounts verwenden eindeutige Pfade (z.B. `/opt/data/…`).
- **mover** — REAL: Kein klassischer Timer-Cronjob im Gast; der Mover läuft
  host-seitig oder wird durch Events getriggert.
- **mergerfs** — COMPOSITION BOUNDARY: Läuft zwingend auf dem **Host**, NICHT im
  Gast; das Gast-System bindet nur die final gemergten Pfade ein.
- **minFreeGb** — CONTRACT-FRAGE (noch keine technische Invariante):
  - Wer konfiguriert ihn, und wer erzwingt ihn?
  - pro Mount oder global?
  - Was bedeutet `0`?
  - Assertion (Eval-Zeit) oder Runtime-Verhalten?

  Solange das offen ist, ist es eine Anforderung, keine fertige Invariante.
