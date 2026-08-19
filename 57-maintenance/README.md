---
id: 57-maintenance
title: Maintenance Domain
description: Cross-cutting background maintenance tasks, DB optimization, and backups.
aliases: [Maintenance, Optimization]
tags: [architecture, medinix, maintenance, sqlite, vacuum]
---

# 57-maintenance: Maintenance Domain

The **Maintenance Domain** (Domain 57) acts as the janitor of mediNix-core. It hosts cross-cutting background jobs that ensure the system remains fast, clean, and reliable over long periods of uptime.

These tasks typically do not serve users or acquire media directly; instead, they operate on the state left behind by other domains.

## 🎯 Core Responsibilities

1. **Database Optimization:** Keeping SQLite databases across all domains in peak condition.
2. **Future:** Automated configuration backups, log rotation enforcement, and certificate health checks.

## 🧩 Services in the Dezimalrahmen

| ID  | Module / Service | Port/UID | Responsibility |
| :--- | :--- | :--- | :--- |
| **571** | [sqlite-wal](571-sqlite-wal.nix) <br> [[ADR-5700]] | N/A | **Database Optimizer**. A scheduled task that enforces Write-Ahead Logging (WAL) and periodically runs `VACUUM`/`ANALYZE` on the databases of dynamically discovered services (like the *arr suite and Jellyfin). |

## 🛡️ Key Architecture Decisions

- **Dynamic Discovery:** Maintenance scripts like `571-sqlite-wal.nix` do not hardcode the directories they maintain. They dynamically read the `registry.nix` at evaluation time to find the active `StateDirectory` paths of enabled services, ensuring maintenance automatically scales as new services are added.
- **Fail-Safe Execution:** Scripts are wrapped in `|| true` guards during locks (e.g., if a database is currently in use) to prevent spurious systemd failures and restart loops.
