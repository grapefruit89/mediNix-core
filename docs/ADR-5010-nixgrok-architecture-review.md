# ADR-5010: mediNix Architecture Review — Nix-Grok Clean AI Homelab (50-core)

## Status: active
## Date: 2026-08-11
## Source: Grok raw "Nix-Grok Review: Clean AI Homelab Architecture" (149 msgs, 433K chars)

## Context
User requested an unvarnished architecture review of the Nix-Grok flake (Fujitsu Q958).
Grok confirmed the 6-layer architecture and the **isomorphism principle** as the core
strength.

## Decision
Adopt the confirmed Nix-Grok patterns into mediNix:
- 6-layer architecture: `flake.nix` → `machines/<host>/` → `users/` → `modules/` →
  `mcp/` → `lib/`
- **Isomorphism principle**: filename `NNss` = UID = Port (decimal framework ADR-5043)
- Clean module separation, no docker/legacy tech (ADR-5000 anti-deprecated)

## Consequences
- ✅ Isomorphism reduces port-conflict headfuck (confirmed by Grok review)
- ✅ 6-layer keeps concerns isolated
- ✅ Fits mediNix decimal framework (51–59)

## Gold-Standard (from Grok)
> "Das Isomorphie-Prinzip (NNss als Dateiname + UID + Port) ist richtig clever.
> Spart extrem viel Headfuck bei Port-Konflikten."
> → ADR-5043 isomorphism is validated, not just invented.
