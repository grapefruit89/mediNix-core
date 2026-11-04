---
id: "ADR-537"
title: "Recyclarr — TRaSH-Guides Sync (declarative)"
domain: 53
status: active
complexity: 3
last_reviewed: 2026-10-16
tags:
  - acquisition
  - arr-stack
  - recyclarr
links:
  adr: ""
  repo-harvest: ""
---
# ADR-537: Recyclarr — TRaSH-Guides Sync (53-acquisition, Dienst 537)

## Status: active
## Date: 2026-10-16
## Source: 53-acquisition/537-recyclarr.nix
## Related: ADR-532 (Sonarr), ADR-0001 (Source-Registry), ADR-0000 (Dezimalrahmen)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **537** (53-acquisition, Slot 7)
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
