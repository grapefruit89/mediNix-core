---
id: 52-security
title: Security Domain (Core & VPN)
description: Manages core system security, break-glass access, and fail-closed VPN policy routing.
aliases: [Security, Hardening, VPN]
tags: [architecture, medinix, security, vpn, wireguard, policy-routing]
---

# 52-security: Security & Hardening Domain

The **Security Domain** (Domain 52) provides the foundational security layer for mediNix-core. It strictly adheres to **Additive Host Integration** (Principle 5) and **Dendritic Modularity**. 

We explicitly do *not* touch global kernel hardening (`boot.kernel.sysctl`), global firewall rules (`networking.firewall`), or central credential loops. Instead, this domain provides surgical, high-precision security tools that domain services can opt into.

## 🛡️ Core Responsibilities

1. **Additive VPN Interfaces:** Declarative provisioning of WireGuard interfaces (`wg0`) that run parallel to the host network without disrupting it.
2. **Fail-Closed Policy Routing (Killswitch):** A hardened, `nftables`-based policy routing engine (Variant 1). It uses `fwmark` and a dedicated routing table to guarantee that confined services (like SABnzbd) can *never* access the physical WAN. It is perfectly fail-closed (no `ExecStop`) and fully dendritic (services register themselves via UID).
3. **Emergency Access:** Providing a break-glass SSH user for disaster recovery scenarios if the primary identity provider fails.

## 📁 Services in the Dezimalrahmen

Each module is strictly configured according to the mediNix Dezimalrahmen convention:

| ID  | Module | Responsibility |
| :--- | :--- | :--- |
| **520** | [core-security](520-core-security.nix) <br> [[ADR-0000]] | Break-glass SSH user (`media-admin`) with Ed25519 key authentication only. |
| **525** | [vpn-interface](525-vpn-interface.nix) <br> [[ADR-5270]] | Declarative WireGuard interface (`wg0`). |
| **526** | [vpn-killswitch](526-vpn-killswitch.nix) <br> [[ADR-5260]] | A pure-Linux policy routing engine (nftables + ip rule) providing absolute Fail-Closed isolation for services that opt-in via `services.vpnKillSwitch.instances`. |

## 🏗️ Key Architecture Decisions

- **Dendritic Credential Management:** Secrets are no longer managed centrally. Instead, each service (e.g., Sonarr, Jellyfin) natively defines its own `LoadCredentialEncrypted` directly in its domain file.
- **No Global Host Tuning:** Global `boot.kernel.sysctl` and default-drop `nftables` configurations were removed to honor Additive Host Integration, ensuring mediNix-core can run on any NixOS host without destroying the host's existing network stack.
- **Fail-Closed Policy Routing (Variant 1):** The killswitch avoids complex BPF hooks or Network Namespaces (which require 3rd-party flakes). It uses exactly one `fwmark`, one routing table, and relies on systemd ordering (`before = [ ... ]`) and the absence of `ExecStop` to guarantee no packets leak, even during service crashes or rebuilds.
