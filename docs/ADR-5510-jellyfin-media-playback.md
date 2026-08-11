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
