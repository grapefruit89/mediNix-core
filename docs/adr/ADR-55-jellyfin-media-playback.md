---
id: "ADR-55-jellyfin-media-playback"
title: "ADR 5510 jellyfin media playback"
domain: 55
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - jellyfin
  - media
  - playback
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5510: Jellyfin — Media Playback Server (55-playback, Dienst 551)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (550-playback/jellyfin, 81 chunks) + ADR-0000
## Related: ADR-5120 (OIDC), ADR-5320 (Sonarr)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **551** (55-playback, _1 Mitte)
- Port: **5510** | UID: **5510** | GID: **5000**

## Context
Jellyfin is the primary media player. Jellyfin-Start depends on `jellyfin.db`
(CLAUDE.md gold-standard). OIDC-SSO via Pocket ID (ADR-5120) for user auth.

## Decision
- Jellyfin native NixOS service, UID 5510, GID 5000
- Start sequence: ensure `jellyfin.db` exists before service start (seccomp needs
  `SystemCallErrorNumber=EPERM`, not kill — CLACDE.md gold-standard)
- OIDC via Caddy `forward_auth` to Pocket ID (ADR-5110/5120)
- Hardware transcoding: device passthrough (VA-API), isolated per ADR-5050

## Consequences
- ✅ Isolated UID 5510, GID 5000 (reads media library)
- ✅ OIDC-SSO, no separate Jellyfin user DB
- ✅ seccomp EPERM prevents hard failures

## Gold-Standard (from CLACDE.md)
> "Jellyfin-Start=jellyfin.db; seccomp braucht SystemCallErrorNumber=EPERM"
> → Hardening detail baked into mkService factory (ADR-5050).

## Operational Notes (migrated from CLAUDE.md, ports corrected 5510)
- **Timing-Bug:** Jellyfin entscheidet an Migrationsstand ob Installation existiert.
  preStart bricht ab solange `/var/lib/jellyfin-5510/data/jellyfin.db` fehlt.
  Vorgaben (config) greifen erst ab 2. Start. Marker = Datenbank, NICHT Config-File
  (config/migrations.xml ist versionsinstabil, database.xml ist stabil).
- **`/var/cache/jellyfin` muss via `systemd.tmpfiles.rules` existieren** (nicht im
  preStart install — dem fehlt CAP_CHOWN). Sonst: `status=226/NAMESPACE` Mount-Fail.
- **GPU/VA-API:** `PrivateDevices=false` (Factory mkForce) — sonst kein /dev/dri sichtbar.
  `SupplementaryGroups=["video"]`. tmpfs `/transcode:size=4G` für HW-Transcode
  (sonst HDD-Transcode tötet Performance).
- **Nicht Version verdächtigen:** 10.11.11 + 10.10.7 scheiterten identisch an
  verschiedenen Tabellen — Ursache war eigener preStart, nicht Upstream.
- **Verify:** `systemctl show jellyfin -p NRestarts --value` (0), `ss -tlnp | grep jellyfin`
  (:5510 nicht :8096), `curl -s -o /dev/null -w '%{http_code}' http://jellyfin.local`
