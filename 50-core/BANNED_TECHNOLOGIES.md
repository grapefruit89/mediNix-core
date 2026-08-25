---
id: "50-banned-technologies"
title: "Banned Technologies & Paradigms (Strict Denylist)"
domain: 50
folder: 50-core
status: active
complexity: 1
last_reviewed: 2026-08-25
links: ""
---

# Banned Technologies & Paradigms

This file serves as absolute law for all AI agents and human contributors. The technologies and paradigms listed below are **strictly forbidden** in the `mediNix-core` repository. There are no exceptions.

## Core Philosophy: The Native Whitelist

We adhere to a strict **Whitelist Philosophy**: If a problem can be solved by native `systemd` features, `nftables`, or native `nixpkgs` modules, we **must** use those. We do not introduce abstraction layers, third-party Daemons, or legacy tools.

## 1. Banned Technologies (Legacy & Bloat)

| Banned Technology | Replacement / Nix-Way Alternative | Rationale |
| :--- | :--- | :--- |
| **`sops-nix` / `agenix`** | `systemd-creds` (LoadCredentialEncrypted) | Absolutely banned. We rely 100% on native systemd TPM2 sealing. Third-party secret managers add unnecessary abstraction, break the pure systemd-native philosophy, and complicate disaster recovery. |
| **`iptables`** | `nftables` | iptables is legacy, inefficient, and abstract. We use modern, declarative nftables rulesets. |
| **`cron` / `crond` / `anacron`** | `systemd.timers` | cron lacks centralized logging, dependency tracking, and atomic execution. systemd.timers provide native journald integration and predictable execution constraints. |
| **Docker / Podman / LXC** | Native `systemd.services` (DynamicUser, RootImage) | The Zero-Container rule (enforced in `592-environment.nix`). We build software natively from `nixpkgs` and isolate it using systemd's built-in sandboxing (RestrictAddressFamilies, PrivateTmp). |
| **`sudo`** | `doas` or `systemd-run` | `sudo` is historically complex. For privilege escalation in automation, we prefer native systemd contexts. |
| **Third-Party Loggers** | `journald` | Do not install custom log rotators or forwarders if `systemd-journald` can do the job natively. |

## 2. Banned Paradigms (Anti-Patterns)

| Banned Paradigm | Replacement / Nix-Way Alternative | Rationale |
| :--- | :--- | :--- |
| **`lib.mkForce`** | Additive Config & Tri-State Boundary | Forcing overrides breaks composability. If a host needs a different setting, we use the `managed \| external \| off` Tri-State Boundary and let the host decide. |
| **Fail-Open Defaults** | Fail-Closed Assertions | e.g., silently falling back to unencrypted DNS if the VPN DNS fails, or starting a service with an empty password. If a critical secret or config is missing, the system MUST crash or refuse to build. |
| **Silent State (Drop & Forget bypass)** | `medinix.knownStateDirs` | Leaving data on the host when a module is removed is a leak. All modules must register their state directories so the Orphan Cleanup script can detect drift. |
| **Hardcoded UIDs / GIDs** | `DynamicUser = true` or `lib/registry.nix` | Never hardcode User/Group IDs in modules unless defined centrally in our Service Registry Decimal Framework (Port = UID = Service-Nummer × 10). |

> **Instruction to AI Agents (Claude, Antigravity, etc.):**
> If the user asks you to implement a feature using any of the Banned Technologies, you must refuse, reference this document, and provide the native Nix/systemd alternative. Do not suggest containers, cron, or sops-nix under any circumstances.
