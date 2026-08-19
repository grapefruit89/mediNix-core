---
id: 52-security
title: Security Domain (Hardening & Networking)
description: Manages core system security, firewall, networking isolation, and secrets.
aliases: [Security, Hardening, VPN]
tags: [architecture, medinix, security, firewall, wireguard, systemd-credentials]
---

# 52-security: Security & Hardening Domain

The **Security Domain** (Domain 52) provides the foundational security layer for mediNix-core. It enforces strict zero-trust principles, kernel-level hardening, and rigorous network isolation to ensure the system is resilient against both internal misconfigurations and external threats.

## 🎯 Core Responsibilities

1. **Network Firewalling (nftables):** Default-drop firewall policies with strict, declarative rules for allowed ingress/egress.
2. **Kernel Hardening (Host-wide):** Restricting BPF, ptrace scoping, ASLR/memory protections, network stack attack surface reduction, and sysctl hardening. *Note: Although defined in this module, NixOS kernel parameters (`boot.kernel.sysctl`, `boot.blacklistedKernelModules`) apply globally to the underlying host.*
3. **Secret Management:** Utilizing `systemd-credentials` (`LoadCredentialEncrypted`) to bind secrets cryptographically to the TPM and specific systemd units, completely eliminating world-readable secret files in the Nix store.
4. **Traffic Confinement (VPN & Killswitch):** Forcing specific high-risk traffic (e.g., Usenet/Torrents) through a dedicated WireGuard VPN interface (`wg0`). The killswitch ensures traffic leaks are mathematically impossible if the VPN drops.
5. **Emergency Access:** Providing a break-glass SSH user for disaster recovery scenarios if the primary identity provider fails.

## 🧩 Services in the Dezimalrahmen

Each module is strictly configured according to the mediNix Dezimalrahmen convention:

| ID  | Module | Responsibility |
| :--- | :--- | :--- |
| **523** | [emergency-user](520-core-security.nix) <br> [[ADR-0000]] | Break-glass SSH user (`media-admin`) with Ed25519 key authentication only. |
| **525** | [vpn-interface](525-vpn-interface.nix) <br> [[ADR-5410]], [[ADR-5270]] | Declarative WireGuard interface (`wg0`), encrypted credential loading, and SABnzbd VPN killswitch confinement. |
| **526** | [vpn-killswitch](526-vpn-killswitch.nix) <br> [[ADR-5260]] | A robust firewall extension that drops any packet from VPN-confined services that attempts to use the physical WAN interface. |

## 🛡️ Key Architecture Decisions

- **Flake-First VPN:** The WireGuard interface (`wg0`) is defined completely declaratively in the Flake (via `networking.wireguard.interfaces`). The host only provides the encrypted private key.
- **TPM-Bound Secrets:** Secrets are encrypted and bound to the host's TPM using `systemd-creds encrypt`. Only the specific systemd service (e.g., `cloudflare-ddns` or `sabnzbd`) is permitted to decrypt its own secret at runtime via `LoadCredentialEncrypted`.
- **Fail-Closed Networking:** The VPN killswitch operates on a fail-closed principle. If `wg0` is down, traffic from confined applications is blackholed by `nftables`, preventing IP leaks.
