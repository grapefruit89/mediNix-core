---
id: "ADR-57-backup-strategy"
title: "ADR 5720 backup strategy"
domain: 57
status: superseded
complexity: 2
last_reviewed: 2026-08-28
tags:
  - backup
  - storage
links:
  adr: ""
  repo-harvest: ""
superseded_by: "ADR-5721 (ADR-57-backup-data-classification.md)"
---
# ADR-5720: Backup Strategy — Borg/Restic on Tier C (57-maintenance)

> **SUPERSEDED 2026-08-28 by ADR-5721** (see docs/adr/ADR-57-backup-data-classification.md).
> Per ADR-0000 (Dezimalrahmen-Verfassung): "nicht loeschen, nicht ersetzen -- nur ergaenzen,
> Status auf superseded" -- this file stays as-is below, only the status changed.
> Reason: the borg-for-media / restic-for-config split described below was never actually
> implemented (576-backup.nix backs up application state only, correctly excludes media --
> media is Class C/reconstructable, not "low-churn data worth deduping"). The real decision,
> grounded in the user's actual constraints (0 EUR/month cloud budget, Koofr already in use,
> a second external disk available), is captured in ADR-5721 together with the A1/A2/B/C
classification this repo now uses. Read ADR-5721 first; this file is historical context only.

## Status: active (historical -- see superseded note above)
## Date: 2026-08-11
## Source: Claude gold_final.json (570-maintenance/backup, 4 chunks) + ADR-5700

## Context
Backups must cover: configs (Tier B SSD), media metadata (Tier C HDD), and the
unified vector store. User discussed bootable-system sticks vs. data backups.

## Decision
- Configs: `restic` → remote (Tower NFS / cloud), daily, encrypted
- Media: `borg` dedupe on Tier C, weekly (low churn)
- Vector store (`embeddings.npy` + `chunks.json`): included in config backup
- No bare-metal recovery stick (homelab, not prod)

## Consequences
- ✅ Deduplicated, encrypted backups
- ✅ Separate config (high-churn) vs media (low-churn) cadence
- ✅ Vector store recoverable

## Gold-Standard (from chat)
> "Du willst ein fertiges, bootbares System auf dem Stick – kein Installer."
> → Rejected: homelab needs data backup, not full-system imaging.
