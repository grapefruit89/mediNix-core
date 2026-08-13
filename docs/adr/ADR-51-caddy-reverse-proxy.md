---
id: "ADR-51-caddy-reverse-proxy"
title: "ADR 5110 caddy reverse proxy"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - caddy
  - ingress
  - proxy
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5110: Caddy Reverse Proxy — systemd-native Ingress (51-ingress, Dienst 511)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (510-ingress/caddy, 336 chunks) + ADR-0000
## Related: ADR-5120 (Pocket ID), ADR-5130 (Cloudflare)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **511** (51-ingress, _1 Zugang)
- Port: **5110** | UID: **5110** | GID: **5000**

## Context
Caddy is the single ingress point for all mediNix services. Zero-Trust audit
confirmed: reverse_proxy, TLS via Cloudflare DNS-01, fail2ban-style banning.

## Decision
- Caddy as native NixOS service (`services.caddy`), no docker
- `reverse_proxy` to `localhost:<service-port>` for each mediNix service
- TLS: Cloudflare DNS-01 challenge (ADR-5130), no CF proxy
- Auth: `forward_auth` to Pocket ID (ADR-5120) for protected routes
- Hardening: `ProtectSystem=strict`, `PrivateTmp`, `NoNewPrivileges` (ADR-5050)

## Consequences
- ✅ Single TLS termination, no per-service certs
- ✅ OIDC at edge via forward_auth
- ✅ UID 5110 isolated, GID 5000 shared (media access)

## Gold-Standard (from chat)
> "Caddy Tower: Zero-Trust Security & Performance Audit" — full audit done,
> reverse_proxy + TLS + fail2ban confirmed solid.
