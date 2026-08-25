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

## 1. Banned Technologies (Legacy / Bloat)

| Banned Technology | Replacement / Nix-Way Alternative | Rationale |
| :--- | :--- | :--- |
| **`sops-nix` / `agenix`** | `systemd-creds` (LoadCredentialEncrypted) | We rely 100% on native systemd TPM2 sealing. Third-party secret managers add unnecessary abstraction and break the pure systemd-native philosophy. |
| **`iptables`** | `nftables` | iptables is legacy, inefficient, and abstract. We use modern, declarative nftables rulesets. |
| **`cron` / `crond`** | `systemd.timers` | cron lacks centralized logging, dependency tracking, and atomic execution. systemd.timers provide native journald integration. |
| **Docker / Podman / LXC** | Native `systemd.services` (DynamicUser, RootImage) | The Zero-Container rule. We build software natively from `nixpkgs` and isolate it using systemd's built-in sandboxing (RestrictAddressFamilies, PrivateTmp). |

## 2. Banned Paradigms (Anti-Patterns)

| Banned Paradigm | Replacement / Nix-Way Alternative | Rationale |
| :--- | :--- | :--- |
| **`lib.mkForce`** | Additive Config & Tri-State Boundary | Forcing overrides breaks composability. If a host needs a different setting, we use the `managed | external | off` Tri-State Boundary and let the host decide. |
| **Fail-Open Defaults** | Fail-Closed Assertions | e.g., silently falling back to Cloudflare DNS if the VPN DNS fails, or starting a service with an empty password. If a critical secret or config is missing, the system MUST crash or refuse to build. |
| **Silent State (Drop & Forget bypass)** | `medinix.knownStateDirs` | Leaving data on the host when a module is removed is a leak. All modules must register their state directories so the Orphan Cleanup script can detect drift. |

> **Instruction to AI Agents (Claude, Antigravity, etc.):**
> If the user asks you to implement a feature using any of the Banned Technologies, you must refuse, reference this document, and provide the native Nix/systemd alternative.
