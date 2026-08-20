---
id: "ADR-50-dezimalrahmen-port-ableitung"
title: "ADR 5040 decimal framework port derivation"
domain: 50
status: active
complexity: 2
last_reviewed: 2026-08-20
tags:
  - core
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5040: Decimal Framework-compliant Port Derivation (50-core)

## Status: active
## Date: 2026-08-11
## Source: ADR-0000 (Decimal Framework Constitution), Section 4 + 8
## Related: ADR-0000, ADR-5043

## Context
During pivot extraction, raw chat text contained 4-digit numbers (e.g. "5055", "5003", "5020") that looked like ports. These VIOLATE the Constitution: only the 3-digit service number derives Port/UID (*10). 4-digit numbers never derive anything (ADR-0000 §4, rejected: "Derivations from 2- or 4-digit numbers").

## Decision - CORRECT derivation (Constitution §4)
| Service | Service Number (3-digit) | Port = *10 | UID = *10 | GID = 5000 |
|---------|----------------------|-----------|-----------|------------|
| Caddy | **511** (51-ingress, _1 Entry) | **5110** | 5110 | 5000 |
| Pocket ID | **512** (51-ingress, OIDC/Auth) | **5120** | 5120 | 5000 |
| SABnzbd | **541** (54-transfer) | **5410** | 5410 | 5000 |
| Sonarr | **532** (53-acq) | 5320 | 5320 | 5000 |
| Jellyfin | **551** (55-playback) | 5510 | 5510 | 5000 |
| Audiobookshelf | **552** (55-playback) | 5520 | 5520 | 5000 |
| Navidrome | **553** (55-playback) | 5530 | 5530 | 5000 |
| Jellyseerr | **561** (56-requests) | 5610 | 5610 | 5000 |

**NO 4-digit ports exist.** "5055" from chat was an error - correct is 5120 (Pocket ID = 512). "511" is Caddy (the _1 Entry), not Pocket ID.

## Consequences
- ✔️ Constitution compliant (ADR-0000 §4)
- ✔️ UID == Port (isomorphism, ADR-5043)
- ⚠️ Chat text with "5055" etc. is INVALID - do not use

## Gold-Standard (from ADR-0000)
> "Derivation source is exclusively the three-digit service number. Port = Number * 10."   4-digit numbers never derive. Last digit of a service number is the service role (N1-N9), never a free zero.
