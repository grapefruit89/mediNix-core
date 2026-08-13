---
id: "ADR-00-source-repository-registry"
title: "ADR 0001 source repository registry"
domain: 00
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - general
links:
  adr: ""
  repo-harvest: ""
---
# ADR-0001: Source Repository Registry (grapefruit89 GitHub Account)

## Status: active
## Date: 2026-08-11
## Source: GitHub MCP search (user:grapefruit89, 20 repos total)
## Purpose: Central pointer to all Nix-related source repos for instant cross-reference.

---

## Nix-Relevant Repositories (name or description contains "nix"/"Nix")

| Repo | URL | Default Branch | Description | Role for mediNix-core |
|------|-----|----------------|-------------|----------------------|
| **mediNix-core** | https://github.com/grapefruit89/mediNix-core | `master` | Portable media-stack boilerplate (english, decimal-framework) | **THIS REPO** — the extracted core |
| **mediNix** | https://github.com/grapefruit89/mediNix | `main` | Living homelab (german, `my.*`-refs, AGENTS.md) | Gold source for real configs + CLAUDE.md gold-standards |
| **devNIX** | https://github.com/grapefruit89/devNIX | `main` | Nix dev tooling + Claude-Code plugin w/ hooks | **Constitution source**: ADR-8000 Decimal Framework = authority over ADR-0000 |
| **Nix-Grok** | https://github.com/grapefruit89/Nix-Grok | `main` | Grok chat-export extractions | Knowledge mining (patterns, pivots) |
| **NixmitGROK** | https://github.com/grapefruit89/NixmitGROK | `main` | Nix + Grok combination | Cross-reference for Grok+Nix patterns |
| **nix-hermes** | https://github.com/grapefruit89/nix-hermes | `main` | (no description) | Hermes+Nix integration — inspect before use |
| **mynixos** | https://github.com/grapefruit89/mynixos | `main` | Personal NixOS setup | Reference for host-specific patterns |
| **mynixos-knowledge-base** | https://github.com/grapefruit89/mynixos-knowledge-base | `main` | Knowledge base | Reference docs, patterns |
| **mynixos-v5** | https://github.com/grapefruit89/mynixos-v5 | `main` | NixOS v5: horizontal modules, hardened security, ABC-tiering, SSO (Pocket-ID), SSoT-registry | **Most advanced reference**: SSO/Pocket-ID + SSoT-registry patterns to port into mediNix-core |

---

## Non-Nix Repos (excluded, listed for completeness)

| Repo | Private | Note |
|------|---------|------|
| FritzBoxBlacklist | no | Fritzbox ad-block |
| Fusion360-CustomThread | no | 3D printing threads |
| Kleinanzeigen-Rental-Analyzer | no | Rental market analysis |
| Neudin | no | Description "Xyz" — unclear, no nix |
| Geniale-Gemini-prompts | no | Gemini prompts |
| DIN-BriefNEO | no | DIN-5008 letter framework |
| caddy-on-steroids | **yes** | Private Caddy config (relevant? inspect if Caddy patterns needed) |
| hermes-backup | **yes** | Private Hermes backup |
| MydealzExporter | **yes** | Private scraper |
| gemini-Gem | no | Gemini integration |
| dumbpadZMK | no | ZMK firmware for keyboard |

---

## How to use this registry

When the user says "look in my other repos":
1. Check `devNIX` first for **decimal-framework / architecture** questions (ADR-8000 is law).
2. Check `mediNix` for **real-world configs** + `CLAUDE.md` gold-standards (Jellyfin start, seccomp EPERM, media-group).
3. Check `mynixos-v5` for **advanced patterns** (SSO/Pocket-ID wiring, SSoT-registry, ABC-tiering).
4. Use `Nix-Grok` / `NixmitGROK` for **chat-extracted knowledge**.

## Rules

- **mediNix-core is the portable extract** — never add `my.*`-refs here (Regel 3, AGENTS.md).
- **devNIX ADR-8000 wins** over any local assumption on numbering.
- **No branch work** in `mediNix` (AGENTS.md Regel −1: main only).
- Private repos (marked **yes**) are out of scope unless explicitly requested.
