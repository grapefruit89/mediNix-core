---
id: "ADR-578"
title: "Drift Detection & Orphan Cleanup"
domain: 57
status: active
complexity: 3
last_reviewed: 2026-10-16
tags:
  - maintenance
  - hygiene
  - state
links:
  adr: ""
  repo-harvest: ""
---
# ADR-578: Drift Detection & Orphan Cleanup (57-maintenance, Dienst 578)

## Status: active
## Date: 2026-10-16
## Source: 57-maintenance/578-orphan-cleanup.nix
## Related: ADR-570 (Storage/Tiering), ADR-521 (Secrets), ADR-0000 (Dezimalrahmen)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **578** (57-maintenance, Slot 8)
- Kein eigener Listener: **Timer** `medinix-orphan-cleanup`
- Ausführung als `User = root` (Zugriff auf `/var/lib/medinix`)

## Context
Jeder Dienst legt unter `/var/lib/medinix` Zustand ab. Wird ein Dienst entfernt
oder umbenannt, bleiben **verwaiste** Verzeichnisse zurück — sie kosten Platz und
tarnen echten Zustand. Das ist Drift zwischen Repo und Maschine.

## Decision
- Ein **Timer** vergleicht die **bekannten** Verzeichnisse (aus Registry/Manifest)
  gegen den Ist-Bestand unter `/var/lib/medinix` und entfernt Unbekanntes.
- **Ignorier-Liste** ist explizit: der Secrets-Ordner und die Crowdsec-Hashdatei
  werden **nie** angefasst.
- Entfernt wird nur, was **nicht** in der Bekannt-Liste steht (Whitelist-Logik,
  kein Blind-`find -delete`).

## Consequences
- ✅ Aufgeräumter State nach Dienst-Umbenennung/-Entfernung
- ✅ Secrets bleiben unberührt (harte Ignorier-Liste)
- ⚠️ Läuft als `root` → Skript bleibt minimal und rein löschend auf engem Pfad
- ⚠️ Die Bekannt-Liste muss vollständig bleiben, sonst gilt ein legitimer Ordner
  als verwaist (deshalb Whitelist statt Blacklist)
