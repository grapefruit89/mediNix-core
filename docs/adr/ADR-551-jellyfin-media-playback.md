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
6. Cache/data: `--datadir /var/lib/jellyfin-5510`, `--cachedir {storage.metadataDir}/jellyfin`.

## Not decided here

- Intro-skipper and other plugins stay out of 551 until they have their own id.
- `SystemCallErrorNumber=EPERM` lives in `lib/hardening-profiles.nix` (dotnet-gpu), not copied into 551.

## Consequences

- Jellyfin appears on the 518 family page only because the module sets `landing` + `iconSvg`.
- Opening `:5510` on the host firewall fails 591 (loopback-only).
- Changing Jellyfin to `public` would put Pocket ID in front and break most apps. Do not.
