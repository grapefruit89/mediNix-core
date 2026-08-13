---
id: "ADR-53-sonarr-series-management"
title: "ADR 5320 sonarr series management"
domain: 53
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - acquisition
  - arr-stack
  - sonarr
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5320: Sonarr — Series Management (53-acquisition, Dienst 532)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (530-acquisition/sonarr, 64 chunks) + ADR-0000
## Related: ADR-5410 (SABnzbd), ADR-5510 (Jellyfin)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **532** (53-acquisition, _3 Mitte)
- Port: **5320** | UID: **5320** | GID: **5000**

## Context
Sonarr manages TV series indexing, grabbing from indexers (Prowlarr) and download
clients (SABnzbd). Needs media library write access (GID 5000).

## Decision
- Sonarr as native NixOS service, UID 5320, GID 5000
- API key via systemd-credentials (ADR-5000), not inline
- Hardening baseline (ADR-5050): `ProtectSystem=strict`, minimal `ReadWritePaths`
- SQLite WAL tuning (ADR-5700): `journal_mode=WAL`, `cache_size=-20000`

## Consequences
- ✅ Isolated UID 5320, shared GID 5000 (library access)
- ✅ WAL prevents SQLite lock contention under load
- ✅ No secret leakage (credentials via systemd)

## Gold-Standard (from chat)
> "Sonarr needs write to media root — GID 5000 shared, UID per-service isolated."
> → Decimal framework GID rule (ADR-0000 §4) in practice.
