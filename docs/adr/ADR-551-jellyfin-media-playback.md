---
id: ADR-551
title: Jellyfin media playback
domain: 55
status: active
last_reviewed: 2026-09-02
tags: [jellyfin, playback, 551]
---

# ADR-551: Jellyfin (service 551)

- **Status:** active
- **Service:** 551 · port **5510** · UID **5510** · GID **5000**
- **Module:** `55-playback/551-jellyfin.nix`
- **Related:** ADR-5110 (Caddy templates), ADR-5120 (Pocket ID is host-wide), ADR-5050 (hardening profiles)

## Context

Jellyfin is the primary video player. First-run state lives in `jellyfin.db`, not in a config file. The process must bind loopback only; 511 publishes `https://jellyfin.{domain}` and `http://jellyfin.local`.

## Decision

1. Native systemd unit, not the nixpkgs `services.jellyfin` module. UID 5510, group `media` (5000), extra groups `video` + `render`.
2. Bind `127.0.0.1:5510` (`JELLYFIN_NetworkConfiguration__LocalNetworkAddresses`). Never `0.0.0.0`.
3. **Ingress:** `accessGroup = "stream"`, `landing = true`, SVG on the vhost. Stream means no Caddy compression and **no forward-auth**. Pocket ID does not wrap Jellyfin; clients talk to Jellyfin's own accounts. That is deliberate — media players break behind OIDC walls.
4. Admin bootstrap password via `LoadCredentialEncrypted` (`medinix.jellyfin.adminPasswordFile` or `medinix.secrets.jellyfinAdminPasswordFile`). Must exist before first start; Jellyfin records setup in the DB.
5. Transcode scratch: `TemporaryFileSystem=/transcode:size=4G`. VA-API via `profiles.dotnet-gpu` (`PrivateDevices=false`, `MemoryDenyWriteExecute=false`).
6. Cache/data separation: `--datadir /var/lib/jellyfin-5510`, `--cachedir {storage.metadataDir}/jellyfin`.

## Storage & Backup Architecture: State ≠ Cache

Jellyfin is split strictly into three functional tiers to maintain small, fast backups while preventing disk-thrashing:

```text
Jellyfin Storage Tiers
│
├── 1. CONFIG / STATE (Backup: /var/lib/jellyfin-5510)
│   ├── config/             (System & network configurations)
│   ├── data/jellyfin.db*   (Critical: users, play states, watched history, bookmarks)
│   └── plugins/            (Installed plugins & configurations)
│
├── 2. CACHE / REGENERABLE (Non-Backup: {storage.metadataDir}/jellyfin on Tier B)
│   ├── metadata/           (Provider artwork, People headshots, library XMLs/JSONs)
│   ├── cache/              (HTTP cache, web client assets via --cachedir)
│   └── /transcode          (Temporary transcode chunks on RAM tmpfs)
│
└── 3. MEDIA (MergerFS: /data)
    ├── /data/movies        (Unified view across SSD hot and HDD cold backends)
    └── /data/series
```

### Critical Gotcha: `--cachedir` is NOT complete metadata separation
- `--cachedir` only relocates Jellyfin's internal HTTP cache and temporary client buffers.
- The heavy artwork collection (especially actor headshots under `metadata/People/` and series banners) defaults to `<datadir>/metadata/`.
- **Precaution:** Blindly moving or bind-mounting all of `/var/lib/jellyfin-5510/data` is forbidden: `jellyfin.db` lives inside `data/` and is essential state. If `jellyfin.db` is moved to a non-backed-up cache tier, database loss on disaster recovery is catastrophic.
- **Implementation Strategy:**
  1. Do not introduce premature, fragile bind-mounts before inspecting the exact version's directory layout on hardware.
  2. Use Jellyfin's native `system.xml` configuration (`<MetadataPath>{storage.metadataDir}/jellyfin/metadata</MetadataPath>`) or an isolated mount for `metadata/` alone.
  3. Validate on target deployment via:
     ```bash
     du -sh /var/lib/jellyfin-5510/*
     du -sh {storage.metadataDir}/jellyfin/*
     ```
     ensuring `/var/lib/jellyfin-5510` remains compact (< 500 MB) with `jellyfin.db` intact.

## Not decided here

- Intro-skipper and other plugins stay out of 551 until they have their own id.
- `SystemCallErrorNumber=EPERM` lives in `lib/hardening-profiles.nix` (dotnet-gpu), not copied into 551.

## Consequences

- Jellyfin appears on the 518 family page only because the module sets `landing` + `iconSvg`.
- Opening `:5510` on the host firewall fails 591 (loopback-only).
- Changing Jellyfin to `public` would put Pocket ID in front and break most apps. Do not.
- Backup scope for Restic covers `/var/lib/jellyfin-5510`, safeguarding user accounts and history without backing up gigabytes of redownloadable images.

