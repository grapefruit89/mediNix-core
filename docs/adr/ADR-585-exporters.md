---
id: "ADR-585"
title: "Exporters — manifest-driven Prometheus exporters"
domain: 58
status: active
last_reviewed: 2026-10-16
tags:
  - observability
  - metrics
  - exportarr
links:
  adr: ""
  repo-harvest: ""
---
# ADR-585: Exporters — Manifest-getriebene Prometheus-Exporters (58-observability, Dienst 585)

## Status: active
## Date: 2026-10-16
## Source: 58-observability/585-exporters.nix
## Related: ADR-040 (gerichtete Abhängigkeiten), ADR-0000 (Dezimalrahmen), L-046

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **585** (58-observability, Slot 5)
- Je Exporter eigener Listener: **Port = 8000 + num** (UID = GID = Port)
- Erzeugt pro exportarr-fähigem Dienst **eine** Unit

## Context
Metriken sollen pro Dienst verfügbar sein, aber jedes Modul, das seinen eigenen
Exporter namentlich kennt, erzeugt Kopplung — und beim nächsten Dienst muss man
wieder Code anfassen.

## Decision
- **Reiner Manifest-Konsument:** `585` kennt **keinen** Dienst namentlich.
  Es iteriert `config.medinix.manifest` und erzeugt für alle Dienste mit
  `metrics.enable && metrics.type == "exportarr"` einen gehärteten
  Exportarr-Dienst.
- Identität je Exporter: eigener **UPG-Account**, `uid = gid = port = 8000 + num`.
- `585` deklariert nur die **Absicht** (`medinix.exporters`); die **Engine** leitet
  die Konten ab (ADR-040 / L-046). Kein Modul schreibt `users.*`, während es das
  Manifest liest — genau das war die Ursache der Infinite Recursion (L-045).

## Consequences
- ✅ Ein neuer Dienst braucht **null** Exporter-Code (nur `metrics.*` im Manifest)
- ✅ Keine Namenskenntnis → keine Kopplung, kein Drift
- ⚠️ Der **Konsument** (Prometheus/VictoriaMetrics/vmagent) fehlt noch →
  Exporter liefern derzeit ins Leere (YAGNI-Entscheidung offen, siehe TODO)
