# ADR-5120: Pocket ID OIDC Module — Env, DB & Security (51-ingress, Dienst 512)

## Status: active
## Date: 2026-08-11
## Source: Grok raw "Pocket ID NixOS Module: Env, DB & Security" (32 msgs, 92K chars)

## Context
User wants a hardened NixOS module for Pocket ID (self-hosted OIDC IdP) — only raw
technical interfaces, no Docker/Ubuntu install guides. Forensically crawled from
official docs.

## Decision
Build Pocket ID as a native NixOS module (no docker):
- Env vars: explicit `environment.etc."pocket-id/env".text` (no secret leakage)
- DB: SQLite (WAL per ADR-5700), path on Tier B SSD
- Security: `RestrictNetworkInterfaces` + `PrivateTmp`, OIDC callback on `*.m7c5.de`
- Integrates with Caddy (ADR-5100 ingress) for TLS + reverse proxy

## Consequences
- ✅ Native systemd service, no container overhead
- ✅ OIDC SSO for Jellyfin/Feishin/arr stack
- ✅ Env isolation prevents secret spill

## Gold-Standard (from Grok)
> "Ich benötige ausschließlich die rohen, technischen Schnittstellen und
> Systemgrenzen — keine Docker/Ubuntu Installationsanleitungen."
> → Module must be NixOS-native, not a docker-compose port.
