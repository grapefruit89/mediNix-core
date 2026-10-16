---
id: "ADR-572"
title: "Recyclarr — TRaSH-Guides Sync (declarative)"
domain: 57
status: active
complexity: 3
last_reviewed: 2026-10-16
tags:
  - maintenance
  - arr-stack
  - recyclarr
links:
  adr: ""
  repo-harvest: ""
---
# ADR-572: Recyclarr — TRaSH-Guides Sync (57-maintenance, Dienst 572)

## Status: active
## Date: 2026-10-16
## Source: 57-maintenance/572-recyclarr.nix
## Related: ADR-532 (Sonarr), ADR-0001 (Source-Registry), ADR-0000 (Dezimalrahmen)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **572** (57-maintenance, Slot 2)
- Kein eigener Listener: periodischer Sync-Task
- Unit: `recyclarr`

## Context
Die arr-Dienste brauchen gepflegte Qualitätsprofile, Custom Formats und
Namensschemata. Das manuell in jeder Weboberfläche zu klicken ist nicht
reproduzierbar und driftet nach jedem Neuaufsetzen.

## Decision
- **Recyclarr** als nativer systemd-Dienst; die Konfiguration wird **deklarativ
  aus dem Repo** gerendert statt von Hand in der App gepflegt.
- **TRaSH-Guides** sind die Upstream-Quelle der Profile (registriert nach
  ADR-0001 / `docs/UPSTREAM-SOURCES.md`).
- Der Sync läuft wiederkehrend, damit Upstream-Verbesserungen ankommen.

## Consequences
- ✅ Qualitätsprofile reproduzierbar aus dem Repo (kein Klick-Drift)
- ✅ Ein Neuaufsetzen konvergiert ohne manuelle Nacharbeit
- ⚠️ Hängt an der Erreichbarkeit der TRaSH-Guides (Upstream-Ausfall = kein Sync)
