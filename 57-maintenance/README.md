---
id: 57-maintenance
title: Maintenance Domain
description: Cross-cutting background maintenance tasks, DB optimization, and backups.
aliases: [Maintenance, Optimization]
tags: [architecture, medinix, maintenance, sqlite, vacuum]
anchors: [lifecycle-management, garbage-collection, defensive-programming, poka-yoke, single-source-of-truth]
---

# 57-maintenance: Maintenance Domain

The **Maintenance Domain** (Domain 57) acts as the janitor of mediNix-core. It hosts cross-cutting background jobs that ensure the system remains fast, clean, and reliable over long periods of uptime.

These tasks typically do not serve users or acquire media directly; instead, they operate on the state left behind by other domains.

## ⚓ Semantic Anchors

- **`Lifecycle Management` / `Garbage Collection`:** Continuous cleaning of transient files, cache rot, and orphaned assets.
- **`Defensive Programming` / `Poka-Yoke`:** Safe state flushing (WAL checkpoints) ensuring zero DB corruption on host power events.
- **`Single Source of Truth`:** Declarative backup manifests and storage path contracts.

## 🎯 Core Responsibilities

1. **Database Optimization:** Keeping SQLite databases across all domains in peak condition.
2. **Future:** Automated configuration backups, log rotation enforcement, and certificate health checks.

## 🧩 Services in the Dezimalrahmen

| ID  | Module / Service | Port/UID | Responsibility |
| :--- | :--- | :--- | :--- |
| **570** | [storage](570-storage.nix) <br> [ADR-570](../docs/adr/ADR-570-storage-tiering-mergerfs.md) | N/A | **Storage & Spindown Zentrum**. Tiering, SetGID, Spindown-Timer, Power-Logging & Piggyback-Mover. |
| **571** | [sqlite-wal](571-sqlite-wal.nix) <br> [ADR-571](../docs/adr/ADR-571-sqlite-wal.md) | N/A | **Database Optimizer**. Enforces WAL and periodically runs `VACUUM`/`ANALYZE` on dynamic service DBs. |
| **575** | [update-notifier](575-update-notifier.nix) | N/A | **Update-Benachrichtigung**. Informiert ueber anstehende Flake-Updates via ntfy. |
| **576** | [backup](576-backup.nix) <br> [ADR-576](../docs/adr/ADR-576-backup.md) | N/A | **Kanonisches Backup**. Restic-Snapshots fuer State (Klasse A) mit DB-Safe Stop/Start & SSH-Pull. |
| **577** | [hygiene](577-hygiene.nix) | N/A | **System-Hygiene**. Drift-Detection und naechtlicher Orphan-Cleanup verwaister Daten. |

## 🛡️ Key Architecture Decisions

- **Dynamic Discovery:** Maintenance scripts like `571-sqlite-wal.nix` do not hardcode the directories they maintain. They dynamically read the `registry.nix` at evaluation time to find the active `StateDirectory` paths of enabled services, ensuring maintenance automatically scales as new services are added.
- **Fail-Safe Execution:** Scripts are wrapped in `|| true` guards during locks (e.g., if a database is currently in use) to prevent spurious systemd failures and restart loops.
