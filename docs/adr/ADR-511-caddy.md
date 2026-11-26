---
id: ADR-511
title: Caddy chameleon ingress
domain: 51
status: active
last_reviewed: 2026-11-26
tags: [caddy, ingress, 511]
---

# ADR-511: Caddy (service 511)

- **Module:** `51-ingress/511-caddy.nix`
- **Port / UID:** 5110 / 5110 · group `caddy` for Lego files (not a catch-all media GID on the daemon)
- **Related:** ADR-512, ADR-513, ADR-514, ADR-518, ADR-551, ADR-552

## Context

One HTTP edge for every registered vhost. Stock `pkgs.caddy`. Certificates come from 514 (Lego DNS-01) or from `tls.mode = custom|internal`. Caddy must not speak ACME.

## Decision (what 511 actually does)

1. **Chameleon.** `ingress.mode`: `auto` reads `services.caddy.enable` and never writes it; `global` injects `virtualHosts`; `standalone` runs `caddy-media` from `/etc/caddy-media/Caddyfile`. Same `allSites` list in both modes.
2. **Sites from `ingress.vhosts` only.** A name is live when the matching `medinix.<name>.enable` is on, the registry has a port, and `accessGroup != none`. 511 does not contain a program list.
3. **Templates & Transport Timeouts.**
   - `stream` (Jellyfin, Audiobookshelf, Navidrome): no `encode` (preserves HTTP 206 Byte-Range streaming and avoids buffering), `flush_interval -1`, `stream_close_delay 5m` (prevents stream/WebSocket cuts across reloads or pause/chunk gaps), and `transport http` with `dial_timeout 5s`, `response_header_timeout 30s`, `read_timeout 300s`, `write_timeout 300s`.
   - `internal` (abort outside `trustedCidrs`), `public` (`encode zstd gzip` + optional `forward_auth`), `idp` (`encode zstd gzip`, no auth, no abort): non-stream routes enforce `transport http` circuit-breaker timeouts (`dial_timeout 5s`, `response_header_timeout 60s`) against hanging backends.
4. **Names.** `https://{name}.{domain}` and optional `dns.hostnames` alias on the wildcard cert. `http://{name}.{domain}` redirects when TLS is on. `http://{name}.lan` is HTTP only — no TLS, no `forward_auth`, CIDR-gated via `lanAbort`.
5. **Landing.** 518 writes HTML into `ingress.landing.root`. 511 serves `http://dashboard.lan` (LAN abort) and optionally `https://{domain}` when `ingress.landing.wanPublic = true`.
6. **Auth Decoupling.** `forward-auth` needs an explicit `forwardAuthUpstream` (oauth2-proxy, ADR-517) + `authProxyPresent = true`. Applied **exclusively** to `accessGroup == "public"` (unless `allowUnauthenticated = true`). `skipPaths` honored. `stream` services (Jellyfin, Audiobookshelf) are **never** wrapped with `forward_auth` because native media players/mobile sync clients break behind OIDC redirects. IdP vhost stays `idp` so login cannot deadlock.
7. **TLS files.** `fullchain.pem` + `key.pem` under `/var/lib/acme/{acmeHost}/`. `auto_https off`. Reload target is `caddy.service` or `caddy-media.service`.
8. **One owner per hostname.** Duplicate site labels fail eval.
9. **Systemd Pacing & Readiness.** Standalone `caddy-media` runs with `Type = "notify"` (`READY=1` via `NOTIFY_SOCKET`), `Restart = "always"`, `RestartSec = "2s"`, and `LimitNOFILE = 1048576` (global `caddy` inherits upstream `Type = "notify"` and `LimitNOFILE = 1048576` as `mkDefault`).

## Not in this module

- Avahi / mDNS policy (515)
- Cloudflare records (513)
- Lego issuance (514)
- Per-app icons (service modules → 518)
- Caddy DNS plugins, CrowdSec, rate-limit builds

## Rejected (old ADR-51 text & pitfalls)

- Caddy does DNS-01 itself — no, 514 does.
- Forward-auth on every service (or on `stream`) — no, only `public`.
- fail2ban inside Caddy — not implemented.
- Systemd `WatchdogSec` on Caddy — rejected: Caddy 2.11 sends `READY=1`/`RELOADING=1`/`STOPPING=1` over `NOTIFY_SOCKET`, **not** `WATCHDOG=1` keepalives; setting `WatchdogSec` causes periodic `SIGABRT` restart loops.
