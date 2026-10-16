---
id: "ADR-515"
title: "mDNS Aliases (Avahi): {service}.local -> LAN-IP"
domain: 51
status: active
complexity: 3
last_reviewed: 2026-10-16
tags:
  - ingress
  - dns
  - avahi
  - mdns
links:
  adr: ""
  repo-harvest: ""
---
# ADR-515: mDNS Aliases — {service}.local (51-ingress, Dienst 515)

## Status: active
## Date: 2026-10-16
## Source: 51-ingress/515-mdns.nix + lib/registry.nix
## Related: ADR-511 (Caddy), ADR-51 (Split-DNS-Hinweis), ADR-0000 (Dezimalrahmen)

## Decimalrahmen (ADR-0000 §4)
- Dienstnummer: **515** (51-ingress, Slot 5)
- Kein eigener Listener: setzt auf **Avahi** (mDNS) auf, kein eigener Port
- Units: `medinix-mdns-aliases` + `medinix-mdns-aliases-restart`

## Context
Dienste sollen im LAN per `<service>.local` erreichbar sein, ohne feste IP oder
gepflegte Host-Dateien auf den Clients. Avahi selbst wird nicht neu gebaut; das
Modul veröffentlicht nur die Aliase.

## Decision
- Nur **aktive** Dienste werden veröffentlicht (Enabled-Filter, Registry-getrieben).
- Drei Lookup-Pfade (direkt, camelCase, `observability.<name>`) — synchron zu
  `511`s `enabledOf` (RT-5): kein Dienst darf über einen Pfad unsichtbar werden.
- Robust statt statisch: das `-restart`-Unit stößt den Alias-Dienst über systemd
  neu an, statt auf einen veralteten Alias zu zeigen.

## Consequences
- ✅ `<service>.local` funktioniert ohne IP-Pflege im Client
- ✅ Neue Dienste erscheinen automatisch (Registry-getrieben, kein Handeintrag)
- ⚠️ mDNS ist **kein** Ersatz für Split-DNS (ADR-51): nur LAN-lokal, kein WAN
