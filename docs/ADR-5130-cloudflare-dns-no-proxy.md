# ADR-5130: Cloudflare DNS for m7c5.de — No Proxy, Direct A-Records (51-ingress)

## Status: active
## Date: 2026-08-11
## Source: Claude gold_final.json (510-ingress/cloudflare, 56 chunks)

## Context
Domain m7c5.de runs over Cloudflare, but all subdomains point via DNS directly to
the homelab IP — no Cloudflare proxy (orange cloud off). This avoids ToS violations
and keeps LAN-speed access.

## Decision
- Cloudflare as DNS-only (gray cloud), direct A/AAAA records to `192.168.2.250`
- Wildcard `*.m7c5.de` resolves to homelab IP, not proxied
- Caddy (ADR-5100) terminates TLS via Cloudflare DNS-01 challenge

## Consequences
- ✅ No Cloudflare bandwidth/proxy limits
- ✅ LAN access stays local (no hairpin through CF)
- ⚠️ No DDoS protection from CF proxy (acceptable: homelab)

## Gold-Standard (from chat)
> "Alle Subdomains zeigen per DNS direkt auf meine Heimadresse – kein Cloudflare-Proxy.
> Damit halte ich mich an deren Regeln."
