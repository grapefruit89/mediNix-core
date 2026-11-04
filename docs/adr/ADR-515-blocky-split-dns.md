---
id: "ADR-515"
title: "Blocky als Split-DNS im Ingress (ersetzt mDNS/Avahi)"
domain: 51
status: active
complexity: 3
last_reviewed: 2026-10-26
tags:
  - dns
  - ingress
  - split-dns
links:
  adr: ""
  repo-harvest: ""
---

# ADR-515: Blocky als Split-DNS im Ingress (ersetzt mDNS/Avahi)

## Status: accepted (2026-10-25)
## Supersedes: archivierte ADR-515-mdns-avahi-aliases (`/home/moritz/repos/mediNix-core/docs/archive/ARCHIVE-ADR-515-mdns-avahi-aliases.md`)

## Context
- WAN-Dienste (`caddyClass` `stream`/`public`) sind ueber `{service}.{domain}` erreichbar. Aus dem LAN muss derselbe Name aufloesbar sein, sonst entsteht Hairpin-NAT (Paket geht zum Router und zurueck).
- Bis 2026-10-25 loeste mDNS/Avahi `{service}.local` auf (`51-ingress/515-mdns.nix`). Das deckte nur `.local` ab, oeffnete UDP/5353 gemaess nixpkgs-Default auf allen Interfaces (Review 2026-10-17, Finding 8) und war nicht deckungsgleich mit den oeffentlichen Namen.
- Split-DNS war zuvor ausdruecklich Host-Sache (`ADR-51-split-dns-note`). Diese Note ist durch die folgende Entscheidung ueberholt.

## Decision
- mediNix betreibt **Blocky** als DNS-Resolver im Ingress: `51-ingress/515-blocky.nix`, Registry `blocky = mkNoPortWithUnit "blocky" 515 "network" "none" "blocky"` (kein TCP-App-Port, Unit vorhanden; HTTP-API auf `127.0.0.1:5150`).
- DNS lauscht auf `0.0.0.0:53`; Upstream ist DoH (`https://1.1.1.1/dns-query`).
- `customDNS.mapping` ist fuer die Zonen `lan` und `<host.domain>` gesetzt (Wert jeweils `127.0.0.1`, `customTTL 1h`, `filterUnmappedTypes`).
- mDNS/Avahi und das Modul `515-mdns` entfallen; UDP/5353 wird nicht mehr geoeffnet.

## Consequences
- ✔ Ein Namensraum (`{service}.{domain}`) statt zweier (`*.local` + oeffentlich).
- ✔ Kein mDNS-Broadcast und kein offener UDP/5353 mehr.
- ⚠ DNS wird zur kritischen Abhaengigkeit: faellt Blocky aus, ist die Namensaufloesung gestoert (Fallback: Router-DNS).
- ⚠ Clients muessen den Host als Resolver nutzen (DHCP/Router-Konfiguration, Host-Sache).
- ⚠ **Offen (zu pruefen):** Das `customDNS`-Mapping zeigt auf `127.0.0.1`. Fuer Clients auf anderen Hosts ist `127.0.0.1` der Client selbst, nicht der Server — wirksam ist das Mapping damit nur fuer den Host. Ob hier die LAN-IP des Hosts stehen muss (und woher sie kommt), ist nicht gemessen.

## Verification
- `dig @<host> <service>.<domain>` und `dig @<host> example.org` (Mapping vs. Forward).
- `ss -lunp | grep :5353` → kein Avahi-Listener.
- `curl -s http://127.0.0.1:5150/api/blocking/status` (Blocky-HTTP-API erreichbar).
- Registry: `grep -n "blocky =" /home/moritz/repos/mediNix-core/50-core/registry.nix`.

## Related
- ADR-511 (Caddy Ingress), ADR-513 (Cloudflare DNS), ADR-514 (ACME)
- ADR-51-split-dns-note (deprecated, Host-Sicht)
