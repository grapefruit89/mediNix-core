---
id: "ADR-52-privesc-audit-hardening"
title: "ADR 5200 privesc audit hardening"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - audit
  - hardening
  - security
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5200: NixOS Privilege Escalation (PrivEsc) Audit & Hardening (52-security)

## Status: active
## Date: 2026-08-11
## Source: Grok raw "NixOS PrivEsc Audit: K2-K6/H3 Review & Plan" (82 msgs, 220K chars)

## Context
User requested a critical, no-assumptions security audit of the NixOS repo (q958) with
focus on Privilege Escalation vectors (K2-K6/H3 taxonomy). Mandate: verify current
state with `rg`/`fd`/`bash`, never guess.

## Decision
Hardening priorities from the audit:
1. **No silent `sudo`/setuid drift** — assert `security.sudo.enable` explicitly, users
   in `wheel` only via declarative `extraGroups`.
2. **Restrict `environment.systemPackages`** — no debug/compiler toolchains on prod.
3. **systemd service hardening baseline** (`ProtectSystem=strict`, `NoNewPrivileges=yes`,
   `PrivateTmp=yes`) applied via `mkService` factory (ADR-5000).
4. **Lockout protection** (ADR-21/595): SSH key-only, anti-lockout triple-path.

## Consequences
- ✅ Declarative sudo/permission model — no drift
- ✅ Service-level privilege isolation
- ✅ Audit-driven, not vibes

## Gold-Standard (from Grok)
> "ANNAHMEN SIND VERBOTEN! Prüfe den aktuellen Zustand zwingend mit Bash (rg, fd)."
> → Security review must be evidence-based, not hallucinated.
