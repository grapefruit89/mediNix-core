---
id: "ADR-57-backup-strategy"
title: "ADR 5720 backup strategy"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - backup
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5720: Backup Strategy — Borg/Restic on Tier C (57-maintenance)

## Status: active
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
