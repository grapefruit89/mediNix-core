---
id: "ADR-51-split-dns-note"
title: "ADR 5115 split dns note"
domain: 51
status: active
complexity: 2
last_reviewed: 2026-08-20
tags:
  - dns
  - ingress
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5115: Split-DNS for stream services (Hairpin-NAT avoidance)

## Status: note (no architecture decision, just documentation)
## Date: 2026-08-11
## Source: User Input (Speedport Custom-DNS, Blocky/AdGuard Alternative)

## Context
Stream services (Jellyfin/ABS/Navidrome/Feishin, caddyClass=stream) are WAN-exposed.
If a client in the LAN accesses `https://jellyfin.m7c5.de`, the resolution must point to the **server's LAN IP** - not the WAN IP (otherwise Hairpin-NAT occurs: the packet goes out to the router, then back in, causing performance loss and potential blockages).

## Decision
**mediNix-core does NOT handle Split-DNS itself.** That is host infrastructure.
Possible solutions (host-side):
- Router with Custom-DNS (e.g., Speedport): `jellyfin.m7c5.de   192.168.2.x` (LAN)
- Blocky / AdGuard Home: Local-zone Override for `*.m7c5.de` -> LAN-IP
- Pi-hole: Local DNS Record

## Consequences
- ✔️ No module code for DNS in mediNix-core (portable remains portable)
- ✔️ Host decides its own DNS strategy
- ⚠️ If host lacks Split-DNS: LAN clients use Hairpin-NAT (works, but is slower). No hard fail.

## Related
- ADR-5110 (caddyClass stream/internal/public/none)
- ADR-5120 (Pocket-ID OIDC)
