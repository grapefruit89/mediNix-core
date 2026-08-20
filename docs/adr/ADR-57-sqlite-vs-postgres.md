---
id: "ADR-57-sqlite-vs-postgres"
title: "ADR 5700 sqlite vs postgres"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-20
tags:
  - postgres
  - sqlite
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5700: SQLite over PostgreSQL as Database Backend

## Status
Accepted (2026-08-11)

## Context
For the media stack (Sonarr, Radarr, Prowlarr, Readarr, Lidarr, SABnzbd), we evaluated whether PostgreSQL should be used instead of SQLite as the central database backend (similar to enterprise deployments or projects like Nixflix).

## Decision
**SQLite with WAL mode and optimized PRAGMAs** is strictly maintained as the exclusive backend. PostgreSQL will not be implemented.

## Rationale
1. **Homelab Context:** <=6 concurrent media services, 1 primary user (plus family). PostgreSQL introduces unnecessary overhead (network sockets, daemon, connection pooling).
2. **Performance:** SQLite with WAL and memory-mapped I/O (`mmap_size=256MB`, `synchronous=NORMAL`) is faster and has lower latency for single-host/single-user workloads than PostgreSQL.
3. **Native Ecosystem:** All *arr services were primarily developed for SQLite; SQLite databases reside directly in the respective service's `StateDirectory` and are inherently protected by systemd isolation.
4. **Maintainability:** No PostgreSQL maintenance, no external credentials, no setup target needed.

## Technical Implementation
- `542-sqlite-wal.nix` applies advanced PRAGMAs event-triggered (after start):
  - `journal_mode=WAL`
  - `synchronous=NORMAL`
  - `cache_size=-20000` (20MB Cache)
  - `temp_store=MEMORY`
  - `mmap_size=268435456` (256MB mmap)
  - `journal_size_limit=67108864` (64MB WAL-Limit)
  - `wal_autocheckpoint=1000`
  - `busy_timeout=5000`

## Appendix: Paperless-ngx Edge Case
While SQLite is sufficient for almost all Homelab applications (*arr, Pocket-ID, Vaultwarden), heavy parallel importers like Paperless-ngx can trigger `database is locked` errors. When running Paperless-ngx on SQLite, it is strongly recommended to throttle the importer (`PAPERLESS_TASK_WORKERS = "1"`) to prevent concurrent write locks.
