# ADR-518-landingpage-honeypot: Minimal Static Landingpage (LAN-only)

## Context
A central entry point (apex domain / `home.local`) is needed for the family to
reach exposed services (Jellyfin, Seerr, Audiobookshelf).

## Decision
- **Minimal Static HTML:** The landing page is a single, static HTML file baked
  into the Nix store (`518-landingpage.nix`) and served by Caddy as a
  `file_server` — a plain grid of `<a href>` tiles. No JavaScript.
- **LAN-only:** The page is served exclusively behind the `trustedCidrs` abort
  (`https://{domain}`, `http://home.local`); `noindex, nofollow, noarchive,
  nosnippet` in the head. WAN requests are aborted, not redirected.
- **Renderer only:** 518 renders exclusively ENABLED stream/public vHosts as
  tiles (H14 — a tile must correspond to a servable vhost) and the link scheme
  follows the actual TLS state (H19). No program names inside 518.

## Removed / never implemented (documented honestly — RT-6, 2026-10-02)

A previous version of this ADR described measures that NEVER existed in code:
- `data-go` attributes + JS redirects and `/go/X` 302 routes instead of `href`s
- hidden honeypot elements (`/.env`, `/wp-admin`)
- CrowdSec's `http-sensitive-files` scenario banning scanner IPs via nftables

Treating them as existing protection would have been dangerous: the security
matrix and this wiki are decision bases. The prerequisite for any log-based
banning — access logs — only landed with RT-3 (511, filtered JSON to journald).
The bouncer itself (CrowdSec, slot 516) remains **planned, not implemented**;
until it exists, a fail2ban jail on the Caddy logs is the sanctioned interim
(519).

## Consequences
- The web server configuration remains completely flat and declarative.
- Zero maintenance for the landing page: no runtime dependencies.
- **Drop & Forget:** the landing page vanishes completely when the stack is
  disabled (`lib.mkIf` on `medinix.enable`).
- Crawler/bot handling is NOT solved by this page — it is future work (516).
