---
id: ADR-511
title: Caddy chameleon ingress
domain: 51
status: active
last_reviewed: 2026-09-02
tags: [caddy, ingress, 511]
---

# ADR-511: Caddy (service 511)

- **Module:** `51-ingress/511-caddy.nix`
- **Port / UID:** 5110 / 5110 · group `caddy` for Lego files (not a catch-all media GID on the daemon)
- **Related:** ADR-512, ADR-513, ADR-514, ADR-518, ADR-551

## Context

One HTTP edge for every registered vhost. Stock `pkgs.caddy`. Certificates come from 514 (Lego DNS-01) or from `tls.mode = custom|internal`. Caddy must not speak ACME.

## Decision (what 511 actually does)

1. **Chameleon.** `ingress.mode`: `auto` reads `services.caddy.enable` and never writes it; `global` injects `virtualHosts`; `standalone` runs `caddy-media` from `/etc/caddy-media/Caddyfile`. Same `allSites` list in both modes.
2. **Sites from `ingress.vhosts` only.** A name is live when the matching `medinix.<name>.enable` is on, the registry has a port, and `accessGroup != none`. 511 does not contain a program list.
3. **Templates.** `stream` (no encode, long timeouts), `internal` (abort outside `trustedCidrs`), `public` (encode + optional `forward_auth`), `idp` (encode, no auth, no abort).
4. **Names.** `https://{name}.{domain}` and optional `dns.hostnames` alias on the wildcard cert. `http://{name}.{domain}` redirects when TLS is on. `http://{name}.local` is HTTP only — no TLS, no auth, no abort.
5. **Landing.** 518 writes HTML into `ingress.landing.root`. 511 serves `https://{domain}` (LAN abort) and `http://home.local`.
6. **Auth.** `forward-auth` needs Pocket ID **or** a non-empty `forwardAuthUpstream`. Applied only to `public`. `skipPaths` honored. IdP vhost stays `idp` so login cannot deadlock.
7. **TLS files.** `fullchain.pem` + `key.pem` under `/var/lib/acme/{acmeHost}/`. `auto_https off`. Reload target is `caddy.service` or `caddy-media.service`.
8. **One owner per hostname.** Duplicate site labels fail eval.

## Not in this module

- Avahi / mDNS policy (515)
- Cloudflare records (513)
- Lego issuance (514)
- Per-app icons (service modules → 518)
- Caddy DNS plugins, CrowdSec, rate-limit builds
- 554-feishin still writes its own `virtualHosts` and bypasses this engine

## Rejected (old ADR-51 text)

- Caddy does DNS-01 itself — no, 514 does.
- Forward-auth on every service — no, only `public`.
- fail2ban inside Caddy — not implemented.
