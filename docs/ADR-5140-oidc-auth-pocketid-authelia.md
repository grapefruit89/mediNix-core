# ADR-5140: OIDC Auth — Pocket ID + Authelia Fallback (51-ingress)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (510-ingress/oidc, 22 chunks) + ADR-5101

## Context
Multiple services (Jellyfin, Feishin, *arr) need SSO. Pocket ID is the primary OIDC
IdP (ADR-5101). Authelia as fallback for services without OIDC support.

## Decision
- Pocket ID as primary OIDC provider, integrated with Caddy (ADR-5100) via
  `forward_auth` middleware
- Authelia as secondary for basic-auth-only apps (SABnzbd, qBittorrent)
- All callback URLs on `*.m7c5.de` (Cloudflare DNS, ADR-5102)

## Consequences
- ✅ Single sign-on across media stack
- ✅ No per-service password sprawl
- ✅ Caddy handles auth at edge (fail-closed)

## Gold-Standard (from chat)
> "curl -sk --resolve pocket-id.m7c5.de:443:192.168.2.250 https://pocket-id.m7c5.de → 200"
> → DNS-resolve test confirms OIDC endpoint reachable before Caddy wiring.
