---
id: "ADR-57-sqlite-wal-tuning"
title: "ADR 5700 sqlite wal tuning"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - sqlite
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5700: SQLite WAL Tuning for *arr Stack (Tier B SSD) (57-maintenance)

## Status: active
## Date: 2026-08-11
## Source: Claude-Index (gold_final.json, 570-maintenance), Grok "SQLite MCP Server"

## Context
*arr services (Sonarr/Radarr/Prowlarr/SABnzbd) use SQLite heavily. On Tier B SSD
this causes write amplification and latency spikes during library scans. The
chat history confirms repeated SQLite lock errors and "database is locked"
during concurrent operations.

## Decision
Apply WAL pragmas to ALL *arr SQLite DBs on Tier B:
```
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -20000;   # ~20MB per connection
PRAGMA temp_store = MEMORY;
```
Implemented via a shared module `536-sqlite-wal.nix` (event-driven VACUUM on
service stop, no legacy cron — ADR-5000 compliant).

## Consequences
- ✅ 4–10x write throughput, no "database locked" under scan load
- ✅ WAL keeps SSD writes sequential (less wear)
- ✅ cache_size=-20000 bounds RAM, temp_store=MEMORY avoids Tier C spill
- ⚠️ WAL needs `-wal`/`-shm` files on same filesystem (Tier B, not mergerfs)

## Gold-Standard (from chat)
> Repeated "database is locked" during Sonarr/Radarr library refresh → resolved
> by WAL + NORMAL sync + 20MB cache. No BERTopic/vector overhead needed for this.
