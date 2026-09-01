---
id: ADR-576
title: Restic A2-only backup
domain: 57
status: active
last_reviewed: 2026-09-02
module: 57-maintenance/576-backup.nix
supersedes: ["ADR-5720"]
related: ["ADR-57-backup-data-classification.md"]
---

# ADR-576: Backup module

**Why.** Stack state (SQLite, API keys) is class A2. Caches and the media library are not. A second tool or a media job adds heat for data we can re-download.

**How.** `576-backup.nix` runs one restic job. Paths = registry `stateDir` of **enabled** services plus `secrets.secretsDir`. Before restic, those units stop (except Caddy). Class B names (`transcodes`, `cache`, `incomplete`, `Downloads`, `logs`) are excludes, not three hardcoded absolute paths.

**Not in this module.** Photos, documents, password-manager files (A1) — host flake. `storage.mediaRoot` (C). SOPS. Borg. ISO/BSI paperwork. Automated restore drills.

**Offsite.** Optional `restic copy` after a successful primary run. Host sets repository (disk or `rclone:koofr:…`) and a systemd credential. No paid object store required.

**Password.** `passwordCredentialPath` first; `passwordFile` only as escape hatch.
