---
id: 52-security
title: Security Domain (Core & VPN)
description: Host baseline, break-glass access, WireGuard, fail-closed killswitch.
aliases: [Security, Hardening, VPN]
tags: [architecture, medinix, security, vpn, wireguard, policy-routing]
last_reviewed: 2026-09-02
---

# 52-security

Additive host integration: no `mkForce` on the host firewall or global sysctl.
Three modules on purpose — not five stubs.

| ID | File | Role |
| --- | --- | --- |
| **520** | [`520-core-security.nix`](520-core-security.nix) | Media GID 5000, optional `media-admin`, `medinix.recommended.*`, optional LUKS+TPM2 |
| **521** | [`521-creds.nix`](521-creds.nix) | Sealed-only systemd-creds; secrets must not live under `mediaRoot` |
| **525** | [`525-vpn-interface.nix`](525-vpn-interface.nix) | Flake-managed WireGuard + systemd credential |
| **526** | [`526-vpn-killswitch.nix`](526-vpn-killswitch.nix) | nftables mark + policy table; services opt in by **UID** |

528 and 529 were header-only organs. Their code now lives in 520. VPN stays split: interface vs killswitch are different failure domains (526 is the large one).

`medinix.recommended.sysctl` is a suggestion list. 520 does not write `boot.kernel.sysctl`.

## Threat model: GID 5000

`Group=media` (GID 5000) plus `UMask=0002` is the **library write domain**.
*arr, SAB and the players must share the same files. That is not a forgotten hole.

It is **not** a secret domain. Compromised Sonarr can rewrite a mkv; it must not be able to rewrite an API key.

- Blobs live in `/var/lib/medinix/secrets/*.encrypted` (`LoadCredentialEncrypted`).
- 521 rejects any secret path under `storage.mediaRoot`.
- Players bind the library read-only. SAB may write only `mediaRoot/downloads`.

## Network boundary

- `lib/hardening-profiles.nix` `base` already sets `RestrictAddressFamilies = AF_UNIX AF_INET AF_INET6 AF_NETLINK`. Script units drop to `AF_UNIX` only. `PrivateNetwork=true` is only for scripts; Arr/Jellyfin must speak TCP.
- 526 matches `meta skuid`. The unit UID is part of the killswitch. Factory users are static; `NoNewPrivileges` + empty caps keep the process on that UID.
- `hostIntegration.firewall = managed` means mediNix may *list* 80/443. It does not enable the host firewall. 520 asserts `networking.firewall.enable` or `networking.nftables.enable` when `managed` is set.
