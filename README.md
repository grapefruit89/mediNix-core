# mediNix-core

Portable NixOS media-stack boilerplate — extracted from the mediNix homelab,
decimal-framework conform, systemd-native, no docker.

## Principles

- **Decimal Framework (ADR-0000):** Port = Dienstnummer × 10, UID = Port,
  GID = 5000 (project × 1000). One number → immediately know the project,
  service, port, UID.
- **Flat structure:** every module is `XX-domain/NNN-service.nix`. No nested
  service folders (breaks flat auto-import).
- **systemd-native:** no docker, no netns. Isolation via systemd serviceConfig.
- **No secrets inline:** systemd-credentials only (ADR-5000).
- **Fail-closed:** security defaults abort the build, never silently pass.

## Layout

```
lib/                 registry, service-factory, abc-tiering
51-ingress/          Caddy (511), Pocket ID (512), Cloudflare DNS (513)
52-security/         nftables, kernel, ssh, systemd-credentials
53-acquisition/      SABnzbd (541), SQLite WAL
54-transfer/         mover
55-playback/         Jellyfin (551), Audiobookshelf (552), Navidrome (553),
                     Feishin (554), cross-service tuning (559)
56-requests/        (Jellyseerr 561 pending)
57-maintenance/      SQLite optimize, provisioning modules
59-guardrails/       assertions, rollout, emergency-user, backup-ssh
docs/                ADRs (ADR-0000 Verfassung + ADR-5000..5720)
```

## Service Map (decimal framework)

| Service        | Num | Port | UID  | GID  | ADR     |
|----------------|-----|------|------|------|---------|
| Caddy          | 511 | 5110 | 5110 | 5000 | ADR-5110|
| Pocket ID      | 512 | 5120 | 5120 | 5000 | ADR-5120|
| Cloudflare DNS | 513 | —    | —    | —    | ADR-5130|
| SABnzbd        | 541 | 5410 | 5410 | 5000 | ADR-5410|
| Sonarr         | 532 | 5320 | 5320 | 5000 | ADR-5320|
| Jellyfin       | 551 | 5510 | 5510 | 5000 | ADR-5510|
| Audiobookshelf | 552 | 5520 | 5520 | 5000 | ADR-5520|
| Navidrome      | 553 | 5530 | 5530 | 5000 | ADR-5530|
| Jellyseerr     | 561 | 5610 | 5610 | 5000 | ADR-5610|

## Docs

See `docs/INDEX.md` for the full ADR list. ADR-0000 is the constitution —
never delete it.

## Status

Boilerplate skeleton. Modules marked `status: draft` or missing ADR modules
are placeholders, not production config. This repo is the *portable core*,
not the living homelab (that lives in grapefruit89/mediNix, German folder names).
