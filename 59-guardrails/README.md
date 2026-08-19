---
id: 59-guardrails
title: Guardrails & Invariants Domain
description: Centralized system for NixOS assertions, invariants, and structural integrity checks.
aliases: [Guardrails, Assertions, Registry]
tags: [architecture, medinix, invariants, assertions, security]
---

# 59-guardrails: Guardrails & Invariants Domain

The **Guardrails & Invariants Domain** (Domain 59) is the safety net of `mediNix-core`. Instead of scattering `assertions` across dozens of individual `.nix` files, this domain centralizes all structural rules, security policies, and sanity checks into a single, highly visible location.

If a developer attempts to misconfigure the system (e.g., exposing a database without TLS, routing a downloader outside the VPN, or putting a secret in the world-readable Nix Store), the guardrails will catch it at evaluation time and abort the NixOS build with a clear, actionable error message.

## 🎯 Core Responsibilities

1. **Central Error Registry (`599-assertion-registry.nix`):** Defines the strict formatting and metadata for every error message, including links to Architecture Decision Records (ADRs).
2. **Structural Integrity:** Enforces the Dezimalrahmen convention (e.g., ensuring ports map correctly to Service IDs).
3. **Security Boundaries:** Enforces policies like preventing Docker/Podman usage, enforcing `nftables`, and strictly forbidding secrets in `/nix/store/`.
4. **Domain-Specific Rules:** Contains isolated rule sets for each domain (Ingress, Security, Transfer, Playback) to keep the logic modular but the location centralized.

## 🧩 Services in the Dezimalrahmen

The `59` domain does not host running services (`systemd` units); it hosts evaluation-time assertions.

| ID  | File | Responsibility |
| :--- | :--- | :--- |
| **590** | `590-guardrails.nix` | The active assertions logic. Centralizes all structural rules, security policies, VPN confinement checks, and storage constraints into a single, clean file. |
| **599** | `599-assertion-registry.nix` | The dictionary of all error codes (e.g., `INV-01`, `VPN-005`), formatting them nicely for terminal output. |

## 🛡️ Key Architecture Decisions

- **Evaluation-Time Abort:** These guardrails use Nix's built-in `assertions` list. If any assertion evaluates to `false`, the entire `nixos-rebuild` command fails instantly before touching the system state.
- **Actionable Error Messages:** Errors are not just generic stack traces. Using `reg.mkErrorDoc`, every failure outputs exactly *what* happened, what was *expected*, how to *fix* it, and a *reference* to the relevant ADR document.
