---
id: "ADR-00-nixmeta-v3"
title: "NIXMETA V3.0 Header Standard"
domain: 00
status: active
complexity: 1
last_reviewed: 2026-08-20
tags:
  - core
  - conventions
links:
  adr: ADR-0000
---

# ADR-00: The NIXMETA V3.0 YAML Header Standard

## Context
To ensure machine readability for LLM agents (like Context7, Kanbans, Code-Audits) and optimize manual navigation for humans, EVERY `.nix` file in the `mediNix-core` repository MUST have a standardized YAML header at the top of the file.

A lot of time and brainpower went into drafting this format. This document secures this knowledge and serves as the central "Single Source of Truth" with tip-top prime examples for One-Shot / Few-Shot Prompts.

## Specification (V3.0)
- The header MUST begin on the first line of the file.
- It MUST be enclosed in Nix comments (`# `).
- It MUST start and end with `# ---` (YAML Frontmatter Syntax).
- It MUST be valid YAML (after removing the `# ` prefixes).

---

## Tip-Top Prime Example 1: Standard Service Module (Minimal)
This example shows the mandatory fields that every normal module (e.g., a guardrail or service) must strictly have.

```nix
# ---
# id: "590-registry"
# title: "Central Error Registry (Invariants + Assertion-Errors)"
# domain: 59
# folder: 59-guardrails
# status: active
# complexity: 2
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-0000 (Decimal Framework Constitution)
# ---
{ config, lib, pkgs, ... }:
# ... nix code ...
```

## Tip-Top Prime Example 2: Complex Core Modules & Libraries
This example shows the maximum format. It is used for libraries (like the registry itself) or highly complex core modules that export dependencies (`provides`) or require external things (`requires`).

```nix
# ---
# id: "registry"
# title: "mediNix SSoT Registry (ports/uid/gid, isomorph)"
# domain: 50
# folder: 50-media
# status: active
# complexity: 4
# last_reviewed: 2026-08-11
# links:
#   adr: ADR-5043
# provides: ["ports", "uids", "services"]
# requires: []
# upstream_docs: ["https://nixos.wiki/wiki/Module_System"]
# forum_links: []
# upstream_github: "https://github.com/grapefruit89/mediNix-core"
# nixpkgs_attr: ""
# state_dir: ""
# uds_socket: false
# systemd_hardened: false
# ---
{ lib, ... }:
# ... nix code ...
```

## Field Explanations

### 🔑 Mandatory Fields (Must always exist)
- `id:` The exact file identifier without `.nix` (e.g., `590-registry`).
- `title:` A short, concise, human-readable title.
- `domain:` The 2-digit domain number (e.g., `59` for Guardrails).
- `folder:` The exact folder name where the file resides (e.g., `59-guardrails`).
- `status:` Lifecycle status (Allowed: `active`, `deprecated`, `draft`).
- `complexity:` 1 (very simple) to 5 (highly complex system architecture).
- `last_reviewed:` ISO date (YYYY-MM-DD) of the last Red-Team Audit.
- `links.adr:` Reference to the primary design decision (e.g., `ADR-0000`).

### 🛠️ Extended Fields (For complex modules)
- `provides:` List of features/contexts this module provides to others.
- `requires:` List of dependencies that must be fulfilled externally.
- `upstream_*`: Metadata for upstream services, GitHub repos, and forum posts for traceability.
- `state_dir:` The primary persistent folder (relevant for backups).
