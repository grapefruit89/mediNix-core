---
id: "ADR-56-seerr-request-management"
title: "ADR 5610 seerr request management"
domain: 56
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - seerr
  - requests
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5610: Seerr — Request Management (56-anfragen, Dienst 561)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (530-acquisition/seerr, 3 chunks) + Grok raw + ADR-0000
## Related: ADR-5320 (Sonarr), ADR-5510 (Jellyfin)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **561** (56-anfragen, _1 Mitte — Request-Management Domain)
- Port: **5610** | UID: **5610** | GID: **5000**

## Context
Seerr handles user requests for media, integrates with Sonarr/Radarr and
notifies Jellyfin. Domain `56-anfragen` is the free-middle slot for request flow.

## Decision
- Seerr native NixOS service, UID 5610, GID 5000
- OIDC via Caddy forward_auth (ADR-5110/5120)
- API keys to Sonarr/Radarr via systemd-credentials (ADR-5000)
- Hardening baseline (ADR-5050)

## Consequences
- ✅ Isolated UID 5610, GID 5000 (shared media)
- ✅ Request flow: Seerr → Sonarr/Radarr → Jellyfin
- ✅ No plaintext API keys

## Gold-Standard (from chat)
> "Seerr = request portal, talks to *arr + Jellyfin via API"
> → Integrates the media pipeline (ADR-5320/5510).
