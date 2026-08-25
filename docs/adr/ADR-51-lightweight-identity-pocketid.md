---
id: "ADR-51-lightweight-identity-pocketid"
title: "ADR 5120 lightweight identity pocketid"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-08-20
tags:
  - ingress
  - pocketid
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5120: PocketID as Lightweight Identity Provider

## Context
We need a central OIDC provider for mTLS and Forward-Auth on the Tower (Layer 40/60).

## Options
1. **Authentik:** Feature-rich, but extremely resource-heavy (PostgreSQL, Redis, Workers).
2. **PocketID:** Lightweight, Go-based, native Passkey focus.

## Decision
We select **PocketID**.

## Rationale
- **Efficiency:** Authentik is too heavy for a single-server setup (Tower).
- **Security:** PocketID promotes the passwordless Aviation-Grade standard.
- **Maintainability:** Fewer dependencies (no external DB strictly required).

## Cross-Domain Wiring
PocketID is automatically enabled and published by Caddy when `medinix.ingress.auth.mode == "forward-auth"`. Its VHost is assigned the `idp` accessGroup to prevent routing loops (where the IdP requires authentication via itself).

## Status
Authentik nuggets remain in the knowledge base only as a **reference for complex Nix modules**, but are ignored in the system design.
