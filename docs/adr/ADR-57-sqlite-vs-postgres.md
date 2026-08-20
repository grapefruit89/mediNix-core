---
id: "ADR-57-sqlite-vs-postgres"
title: "ADR 5700 sqlite vs postgres"
domain: 57
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - postgres
  - sqlite
  - storage
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5700: SQLite über PostgreSQL als Datenbank-Backend

## Status
Accepted (2026-08-11)

## Kontext
Für den Mediastack (Sonarr, Radarr, Prowlarr, Readarr, Lidarr, SABnzbd) wurde evaluiert, ob PostgreSQL statt SQLite als zentrales Datenbank-Backend eingesetzt werden soll (analog zu Enterprise-Deployments oder Projekten wie Nixflix).

## Entscheidung
**SQLite mit WAL-Modus und optimierten Pragmas** wird als ausschließliches Backend beibehalten. PostgreSQL wird nicht implementiert.

## Begründung
1. **Heimlabor-Kontext:** ≤6 gleichzeitige Mediendienste, 1 primärer Nutzer (plus Familie). PostgreSQL erzeugt unnötigen Overhead (Netzwerk-Socket, Daemon, Connection-Pool).
2. **Performance:** SQLite mit WAL und Memory-Mapped I/O (`mmap_size=256MB`, `synchronous=NORMAL`) ist für Single-Host/Single-User-Workloads schneller und latenzfreier als PostgreSQL.
3. **Natives Ökosystem:** Alle Arr-Dienste wurden primär für SQLite entwickelt; SQLite-Datenbanken liegen direkt im `StateDirectory` des jeweiligen Services und sind inhärent durch systemd-Isolation geschützt.
4. **Wartbarkeit:** Keine PostgreSQL-Wartung, keine externen Credentials, kein Setup-Target nötig.

## Technische Umsetzung
- `542-sqlite-wal.nix` wendet event-getriggert (nach Start) erweiterte Pragmas an:
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
