---
id: "ADR-5210"
title: "ADR 5210 nftables firewall baseline"
domain: 52
status: active
complexity: 2
last_reviewed: 2026-08-12
tags:
  - firewall
  - security
links:
  adr: ""
  repo-harvest: ""
---
# ADR-5210: nftables Firewall Baseline — Native, No iptables (52-security)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (520-security/firewall, 30 chunks) + ADR-5043

## Context
User historically used `iptables -A INPUT ...` for quick port opens. This is
deprecated (ADR-5000 anti-deprecated). NixOS uses nftables natively.

## Decision
- Firewall via `networking.firewall` (nftables backend), NO `iptables` commands
- `allowedTCPPorts` declarative in mediNix modules
- Default DROP on WAN, allow LAN + VPN subnets
- SSH (22) + Backup-SSH (2222) only, key-only (ADR-21/595)

### Kernel-nahe Ablösung von Caddy-Plugins (D-27-01 & D-27-03)
*Quelle: `todo/blocks/27-caddy-plugin-replacements.json`*

1. **GeoIP-Filterung via nftables (D-27-01):**
   - User-Space-Plugins wie `caddy-geoip` werden verworfen. Unerwünschter Länder-Traffic wird kernel-nah auf Layer 4 via nftables GeoIP-Sets verworfen, bevor TCP-Handshakes, TLS-Terminierung oder HTTP-Parsing Server-Ressourcen binden.
2. **Rate-Limiting via nftables (D-27-03):**
   - Anstelle von `caddy-ratelimit` wird Ratenbegrenzung kernel-nah via nftables `limit rate` auf unverschlüsseltem Port 80 erzwungen (`tcp dport 80 meter flood-http ... drop`).
   - Port 443 bleibt von generischem L4-Rate-Limiting ausgenommen, um legitime hochbitratige Medien-Streams (Jellyfin, Navidrome) nicht zu beeinträchtigen. Scan-Abwehr auf Layer 7 erfolgt passiv via CrowdSec-Bans.

## Consequences
- ✅ Declarative, reproducible firewall
- ✅ No legacy iptables drift
- ✅ Fits ADR-5043 (systemd-native, no bash/iptables)
- ✅ Kernel-near protection without Caddy custom builds or user-space overhead

## Gold-Standard (from chat)
> "Firewall auf NixOS blockiert Port 4000. Kurz öffnen: iptables -A INPUT ..."
> → Anti-pattern: this is deprecated. Use `networking.firewall.allowedTCPPorts`.
