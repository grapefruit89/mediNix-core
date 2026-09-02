---
id: 52-security
title: Security Domain (Core, Credentials & VPN)
description: Foundational host security, sealed systemd credentials, break-glass access, WireGuard and fail-closed VPN confinement.
aliases: [Security, Hardening, Credentials, VPN]
tags: [architecture, medinix, security, systemd-creds, wireguard, nftables, policy-routing]
last_reviewed: 2026-09-02
---

# 52-security: Security & Hardening Domain

Additive host integration. Domain 52 does not force `networking.firewall.enable`, global default-drop, or `boot.kernel.sysctl`. Hosts opt in.

Four modules. 528 and 529 were stubs; their leftovers live in 520. Do not recreate them.

## Module map

| ID | Module | Responsibility |
| --- | --- | --- |
| **520** | [`520-core-security.nix`](520-core-security.nix) | GID 5000, optional `media-admin`, `medinix.recommended.*`, optional LUKS+TPM2 |
| **521** | [`521-creds.nix`](521-creds.nix) | Sealed-only `systemd-creds` policy at eval time |
| **525** | [`525-vpn-interface.nix`](525-vpn-interface.nix) | WireGuard interface + encrypted private key |
| **526** | [`526-vpn-killswitch.nix`](526-vpn-killswitch.nix) | UID mark + policy routing + unreachable fallback |

## Credentials

```
encrypted blob on disk
        ↓
LoadCredentialEncrypted
        ↓
/run/credentials/<unit>/
        ↓
service reads at runtime
```

`lib/creds.nix` validates the path. `521` enforces it. Service modules declare their own `LoadCredentialEncrypted`.

Accepted names: `*.encrypted`, `*.cred`, `/etc/credstore.encrypted/…`.
Rejected: `dns.ddns.tokenFile`, `passwordFile`, anything under `storage.mediaRoot`, `secrets.autoGenerate`.
Store: `/var/lib/medinix/secrets/`.

## VPN

```
525 interface
        ↓
526 killswitch
        ├─ nftables mark by UID
        ├─ policy table
        └─ unreachable default if the VPN route is gone
```

526 is **not** "absolute isolation". Confined UIDs may still reach loopback, RFC1918/ULA, and the VPN iface. Everything else is drop. WAN without the tunnel is the thing that fails closed.

## Break-glass

`media-admin` is SSH-key only. sudo is `systemctl restart <registry unit>` and `systemctl status * --no-pager`. No shell, no `nixos-rebuild`.

## Threat model: GID 5000

`Group=media` plus `UMask=0002` is the library write domain. Compromised Sonarr can rewrite an mkv. It must not rewrite an API key. Secrets stay off `mediaRoot`. Players bind the library read-only; SAB writes only `mediaRoot/downloads`.

## Host firewall

`hostIntegration.firewall = managed` lists 80/443. It does not enable the firewall. 520 asserts `networking.firewall.enable` or `networking.nftables.enable` when `managed` is set.

`medinix.recommended.sysctl` is a suggestion list. 520 does not write `boot.kernel.sysctl`.

## Agent rule

1. No plaintext secret path.
2. Validate with `lib/creds.nix`.
3. Use `LoadCredentialEncrypted`.
4. Do not silently widen 526 allow-rules into WAN.
5. Keep 525 and 526 separate.
6. Do not bring back 528/529.
7. When the module tree changes, update this file and `AGENTS.md`.
