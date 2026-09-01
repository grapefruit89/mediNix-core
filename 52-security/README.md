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
| **525** | [`525-vpn-interface.nix`](525-vpn-interface.nix) | Flake-managed WireGuard + systemd credential |
| **526** | [`526-vpn-killswitch.nix`](526-vpn-killswitch.nix) | nftables mark + policy table; services opt in by UID |

528 and 529 were header-only organs. Their code now lives in 520. VPN stays split: interface vs killswitch are different failure domains (526 is the large one).

`medinix.recommended.sysctl` is a suggestion list. 520 does not write `boot.kernel.sysctl`.
